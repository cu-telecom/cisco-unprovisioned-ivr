# Note: Each FSM must play media for the IVR to work properly.
#       We bodge this by playing silence

#------------------------
# Initialization
#------------------------
requiredversion 2.0

proc init { } {
    global param
    set param(interruptPrompt) true
    set param(abortKey) *
    set param(terminationKey) #
    set param(maxDigits) 1
    set param(initialDigitTimeout) 1
    set param(interDigitTimeout) 5
    set param(retryCount) 0
    set param(maxRetries) 3
    set param(circuitRetryCount) 0
    set param(maxCircuitRetries) 3
}

#------------------------
# Setup Call
#------------------------
proc act_Setup { } {
    global param
    puts "DEBUG: Setup incoming call"
    leg proceeding leg_incoming
    leg connect leg_incoming
    media play leg_incoming "_unprovisioned_rcu.au"
    leg collectdigits leg_incoming param
}

#------------------------
# Handle Digit
#------------------------
proc act_HandleDigit { } {
    global param
    set status [infotag get evt_status]
    set digit [infotag get evt_dcdigits]
    puts "DEBUG: Collected digit = $digit"

    if { $status == "cd_005" } {
        # Reset menu retry count on input
        set param(retryCount) 0

        switch $digit {
            default {
                puts "DEBUG: Digit Pressed"
                media play leg_incoming "_silence_1.au"
                set param(circuitRetryCount) 0
                fsm setstate PLAY_CIRCUIT_ID
            }
        }
    } elseif { $status == "cd_001" } {
        puts "DEBUG: Timeout waiting for input"
        media play leg_incoming "_silence_1.au"
        fsm setstate REPEATMENU
    } elseif { $status == "cd_007" } {
        puts "DEBUG: Digit collection cancelled"
        call close
    }
}

#------------------------
# Repeat Menu
#------------------------
proc act_RepeatMenu { } {
    global param

    incr param(retryCount)
    puts "DEBUG: Retry attempt $param(retryCount)"

    if { $param(retryCount) >= $param(maxRetries) } {
        puts "DEBUG: Max retries reached. Ending call."
        media play leg_incoming "_silence_1.au"
        fsm setstate CLEANUP
        return
    }

    puts "DEBUG: Replaying menu"
    media play leg_incoming "_unprovisioned_rcu.au"
    leg collectdigits leg_incoming param
}

#------------------------
# Play Circuit ID Prompt Multiple Times
#------------------------
proc act_PlayCircuitID { } {
    global param

    incr param(circuitRetryCount)
    puts "DEBUG: Circuit ID attempt $param(circuitRetryCount)"

    set ani [infotag get leg_ani]
    media play leg_incoming "_your_circuit_id.au %p$ani"

    if { $param(circuitRetryCount) >= $param(maxCircuitRetries) } {
        puts "DEBUG: Finished repeating circuit ID"
        fsm setstate CLEANUP
        return
    }

}

#------------------------
# Cleanup
#------------------------
proc act_Cleanup { } {
    puts "DEBUG: Call cleanup"
    call close
}

#------------------------
# State Machine
#------------------------
init

set MyFSM(CALL_INIT,ev_setup_indication)     "act_Setup, GET_DIGIT"
set MyFSM(CALL_INIT,ev_handoff)              "act_Setup, GET_DIGIT"
set MyFSM(CALL_INIT,ev_disconnected)         "act_Cleanup, CALL_END"

set MyFSM(GET_DIGIT,ev_collectdigits_done)   "act_HandleDigit, CLEANUP"
set MyFSM(REPEATMENU,ev_media_done)          "act_RepeatMenu, GET_DIGIT"
set MyFSM(PLAY_CIRCUIT_ID,ev_media_done)     "act_PlayCircuitID, PLAY_CIRCUIT_ID"

set MyFSM(CLEANUP,ev_media_done)             "act_Cleanup, CALL_END"
set MyFSM(CALL_END,ev_disconnect_done)       "act_Cleanup, same_state"
set MyFSM(CALL_END,ev_media_done)            "act_Cleanup, same_state"
set MyFSM(CALL_END,ev_disconnected)          "act_Cleanup, same_state"

fsm define MyFSM CALL_INIT
