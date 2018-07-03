#!/usr/bin/env bash

##
# @file pr-audit-build-tizen.sh
# @brief Build package with gbs command  to verify build validation on Tizen software platform
#
# @see https://source.tizen.org/documentation/reference/git-build-system
#
# @requirement
# $ sudo apt install gbs

# @brief [MODULE] TAOS/pr-audit-build-tizen-trigger-queue
function pr-audit-build-tizen-trigger-queue(){
    message="Trigger: queued. There are other build jobs and we need to wait.. The commit number is $input_commit."
    cibot_pr_report $TOKEN "pending" "TAOS/pr-audit-build-tizen" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"
}

# @brief [MODULE] TAOS/pr-audit-build-tizen-trigger-run
function pr-audit-build-tizen-trigger-run(){
    echo "[DEBUG] Starting CI trigger to run 'gbs build (for Tizen)' command actually."
    message="Trigger: running. The commit number is $input_commit."
    cibot_pr_report $TOKEN "pending" "TAOS/pr-audit-build-tizen" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"
}

# @brief [MODULE] TAOS/pr-audit-build-tizen
function pr-audit-build-tizen(){
    ## [MODULE] TAOS/pr-audit-build-tizen: Check if 'gbs build' can be successfully passed.
    echo "[MODULE] TAOS/pr-audit-build-tizen: Check if 'gbs build' can be successfully passed."
    pwd

    # check if dependent packages are installed
    # the required packages are gbs.
    check_package sudo
    check_package curl
    check_package gbs

    if [[ $BUILD_MODE == 99 ]]; then
        echo -e "BUILD_MODE = 99"
        echo -e "Skipping 'gbs build' procedure temporarily."
    elif [[ $BUILD_MODE == 1 ]]; then
        echo -e "BUILD_MODE = 1"
        sudo -Hu www-data gbs build \
        -A x86_64 \
        --clean \
        --define "_smp_mflags -j${CPU_NUM}" \
        --define "_pr_context pr-audit" \
        --define "_pr_number ${input_pr}" \
        --define "__ros_verify_enable 1" \
        --define "_pr_start_time ${input_date}" \
        --define "_skip_debug_rpm 1" \
        --buildroot ./GBS-ROOT/  | tee ../report/build_log_${input_pr}_tizen_output.txt
    else
        echo -e "BUILD_MODE = 0"
        sudo -Hu www-data gbs build \
        -A x86_64 \
        --clean \
        --define "_smp_mflags -j${CPU_NUM}" \
        --define "_pr_context pr-audit" \
        --define "_pr_number ${input_pr}" \
        --define "__ros_verify_enable 1" \
        --define "_pr_start_time ${input_date}" \
        --define "_skip_debug_rpm 1" \
        --buildroot ./GBS-ROOT/ 2> ../report/build_log_${input_pr}_tizen_error.txt 1> ../report/build_log_${input_pr}_tizen_output.txt
    fi
    result=$?
    echo "[DEBUG] The variable result value is $result."
    
    if [[ $BUILD_MODE == 99 ]]; then
        # Do not run "gbs build" command in order to skip unnecessary examination if there are no buildable files.
        echo -e "BUILD_MODE == 99"
        echo -e "[DEBUG] Let's skip the 'gbs build' procedure because there is not source code. All files may be skipped."
        echo -e "[DEBUG] So, we stop remained all tasks at this time."
    
        message="Skipped gbs build procedure. No buildable files found. Commit number is $input_commit."
        cibot_pr_report $TOKEN "success" "TAOS/pr-audit-build-tizen" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"
    
        message="Skipped gbs build procedure. Successfully all audit modules are passed. Commit number is $input_commit."
        cibot_pr_report $TOKEN "success" "(INFO)TAOS/pr-audit-all" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"
    
        echo -e "[DEBUG] All audit modules are passed (gbs build procedure is skipped) - it is ready to review!"
    else
        echo -e "BUILD_MODE != 99"
        echo -e "[DEBUG] The return value of gbs build command is $result."
        # Let's check if build procedure is normally done.
        if [[ $result -eq 0 ]]; then
                echo "[DEBUG][PASSED] Successfully build checker is passed. Return value is ($result)."
                check_result="success"
        else
                echo "[DEBUG][FAILED] Oooops!!!!!! build checker is failed. Return value is ($result)."
                check_result="failure"
                global_check_result="failure"
        fi
    
        # Let's report build result of source code
        if [[ $check_result == "success" ]]; then
            message="Successfully a build checker is passed. Commit number is '$input_commit'."
            cibot_pr_report $TOKEN "success" "TAOS/pr-audit-build-tizen" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"
        else
            message="Oooops. A build checker is failed. Resubmit the PR after fixing correctly. Commit number is $input_commit."
            cibot_pr_report $TOKEN "failure" "TAOS/pr-audit-build-tizen" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"
    
            # comment a hint on failed PR to author.
            message=":octocat: **cibot**: $user_id, A builder checker could not be completed because one of the checkers is not completed. In order to find out a reason, please go to ${CISERVER}${PRJ_REPO_UPSTREAM}/ci/${dir_commit}/."
            cibot_comment $TOKEN "$message" "$GITHUB_WEBHOOK_API/issues/$input_pr/comments"
        fi
    fi
    
}
