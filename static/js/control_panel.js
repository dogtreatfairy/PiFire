// Control Panel/Tool Bar JS

// Setup Global Variables 
var cpMode = "Init";
var cpLastMode = "Init";
var splus_state = true;
var last_splus_state = false; 
var pwm_control = false;
var last_pwm_control = false;
var cp_primary_setpoint = 0;
var last_primary_setpoint = -1;
var cp_units = 'F';
var cpRecipeMode = false;
var cpRecipeStep = 0;
var cpRecipeLastStep = -1;
var cpRecipePause = false;
var cpLastRecipePause = false;
var cpRecipeTriggered = false;
var cpLastRecipeTriggered = false;
var cpRecipeStepData = {};

// API Calls
function api_post(postdata) {
    $.ajax({
        url : '/api/control',
        type : 'POST',
        data : JSON.stringify(postdata),
        contentType: "application/json; charset=utf-8",
        traditional: true,
        success: function (data) {
            console.log('API Post Call: ' + data.control);
        }
    });
};

// General Functions 
function setPrime(prime_amount, next_mode) {
    var postdata = { 
        'updated' : true,
        'mode' : 'Prime',
        'prime_amount' : prime_amount,
        'next_mode' : next_mode	
    };
    api_post(postdata);
};

function changeOutput(output) {
    // Fetch the current state from the server
    $.ajax({
        url: '/api/control',
        type: 'GET',
        success: function (control) {
            var state = control.control.manual[output] ? 'on' : 'off';
            var newState = (state === 'on') ? 'off' : 'on';

            var postdata = {};
            postdata['change_output_' + output] = (newState === 'on') ? 'on' : 'off';

            $.ajax({
                url: '/manual',
                type: 'POST',
                data: postdata,
                success: function(response) {
                    console.log(output + ' changed to ' + newState);
                    updateButtonStyle(output, newState);
                },
                error: function(error) {
                    console.error('Error changing ' + output + ' to ' + newState);
                }
            });
        },
        error: function(error) {
            console.error('Error fetching current state for ' + output);
        }
    });
}

function updateButtonStyle(output, state) {
    var button = $("button[data-output='" + output + "']");
    if (state === 'on') {
        if (output === 'fan') {
            button.removeClass('btn-outline-secondary text-primary').addClass('btn-primary text-white');
        } else if (output === 'auger') {
            button.removeClass('btn-outline-secondary text-success').addClass('btn-success text-white');
        } else if (output === 'igniter') {
            button.removeClass('btn-outline-secondary text-warning').addClass('btn-warning text-white');
        }
    } else {
        if (output === 'fan') {
            button.removeClass('btn-primary text-white').addClass('btn-outline-secondary text-primary');
        } else if (output === 'auger') {
            button.removeClass('btn-success text-white').addClass('btn-outline-secondary text-success');
        } else if (output === 'igniter') {
            button.removeClass('btn-warning text-white').addClass('btn-outline-secondary text-warning');
        }
    }
	$("#manual_fan").blur();
	$("#manual_auger").blur();
	$("#manual_igniter").blur();
}

function update_mode() {
    console.log('Detected MODE change.');
    // Hide all toolbars initially
    $("#stopped_group, #startup_group, #active_group, #shutdown_group, #manual_group, #recipe_group").hide();

    // Show relevant toolbar based on mode
    if (cpMode === 'Startup' || cpMode === 'Reignite') {
        $("#startup_group").show();
    } else if (cpMode === 'Manual') {
        $("#manual_group").show();
    } else if (cpMode === 'Smoke' || cpMode === 'Hold') {
        $("#active_group").show();
    } else if (cpMode === 'Shutdown') {
        $("#shutdown_group").show();
    } else if (cpMode === 'Recipe') {
        $("#recipe_group").show();
    } else { // Stop or Error
        $("#stopped_group").show();
        if (cpMode === 'Error') $("#error_group").show();
        else $("#error_group").hide();
    }

    // Reset all buttons to their default styles
    $("#smoke_active_btn").removeClass().addClass("btn btn-outline-warning border border-secondary text-white");
    $("#hold_active_btn").removeClass().addClass("btn btn-outline-success border border-secondary text-white").html('<i class="fas fa-crosshairs"></i>');
    $("#prime_btn").removeClass().addClass("btn btn-outline-secondary border border-secondary dropdown-toggle text-white");

    // Highlight Active Mode Button
    if (cpMode === 'Smoke') {
		document.getElementById("smoke_active_btn").className = "btn btn-warning border border-secondary text-white";
    } else if (cpMode === 'Hold') {
        document.getElementById("hold_active_btn").className = "btn btn-success border border-secondary text-white";
        $("#hold_active_btn").html(cp_primary_setpoint + "°" + cp_units);
    } else if (cpMode === 'Prime') {
        document.getElementById("prime_btn").className = "btn btn-primary border border-secondary dropdown-toggle text-white";
    }

	$("button").blur();
    cpLastMode = cpMode;
}

function update_recipe_mode() {
    var cpRecipeModeIcon = '<i class="far fa-frown"></i>';
    // Update control panel buttons if step changed
    console.log('Detected MODE change.')
    $("#cp_recipe_step_btn").html("Step " + cpRecipeStep);
    // Update Mode button 
    $("#cp_recipe_mode_btn").removeClass("btn-success btn-primary btn-warning btn-success btn-info"); // Remove all potential classes
    if(['Startup', 'Reignite'].includes(cpMode)) {
        cpRecipeModeIcon = '<i class="fas fa-play"></i>';
        $("#cp_recipe_mode_btn").addClass("btn btn-success");       
    } else if(cpMode == 'Prime') {
        cpRecipeModeIcon = '<i class="fas fa-angle-double-right"></i>';
        $("#cp_recipe_mode_btn").addClass("btn btn-primary");
    } else if(cpMode == 'Smoke') {
        cpRecipeModeIcon = '<i class="fas fa-cloud"></i>';
        $("#cp_recipe_mode_btn").addClass("btn btn-warning"); 
    } else if(cpMode == 'Hold') {
        cpRecipeModeIcon = '<i class="fas fa-crosshairs"></i>&nbsp; ' + cp_primary_setpoint + "°" + cp_units;
        $("#cp_recipe_mode_btn").addClass("btn btn-success"); 
    } else if(cpMode == 'Shutdown') {
        cpShutdown();
    };
    $("#cp_recipe_mode_btn").html(cpRecipeModeIcon);
    cpRecipeLastStep = cpRecipeStep;
    cpLastMode = cpMode;
};

function update_recipe_pause() {
    if (cpRecipePause && cpRecipeTriggered) {
        //$("#cp_recipe_next_step_btn").html('<i class="fas fa-step-forward"></i>');
        document.getElementById("cp_recipe_next_step_btn").className = "btn btn-info text-white glowbutton";
    } else {
        //$("#cp_recipe_next_step_btn").html('<i class="fas fa-step-forward"></i>');
        document.getElementById("cp_recipe_next_step_btn").className = "btn btn-info text-white";
    };
    cpLastRecipePause = cpRecipePause;
    cpLastRecipeTriggered = cpRecipeTriggered;
};

function update_splus() {
    // Update splus buttons if splus_state changed
    console.log('Detected SPLUS change.')
    if ((cpMode == 'Smoke') || (cpMode == 'Hold')) {
        console.log('** Updating SPLUS. **')
        if (splus_state == true) {
            $("#splus_btn").show();
            document.getElementById("splus_btn").className = "btn btn-primary border border-secondary shadow mr-2";
        } else {
            $("#splus_btn").show();
            document.getElementById("splus_btn").className = "btn btn-outline-primary border border-secondary text-white mr-2";
        };
    };
    last_splus_state = splus_state;
	$("button").blur();
};

function update_setpoint() {
    // Update Primary Setpoint if it has changed
    console.log('Detected Primary SETPOINT change.')
    if (cpMode == 'Hold') {
        $("#hold_active_btn").html(cp_primary_setpoint + "°" + cp_units);
    } else {
        $("#hold_active_btn").html("<i class=\"fas fa-crosshairs\"></i>");
    };
    last_primary_setpoint = cp_primary_setpoint;
};

function update_pwm() {
    // Update PWM button if pwm_control changed
    console.log('Detected PWM change.')
    if (cpMode == 'Hold') {
        if (pwm_control == true) {
            $("#pwm_control_btn").show();
            document.getElementById("pwm_control_btn").className = "btn btn-primary border border-secondary mr-2";
        } else {
            $("#pwm_control_btn").show();
            document.getElementById("pwm_control_btn").className = "btn btn-outline-primary border border-secondary text-white mr-2";
        };
    } else {
        $("#pwm_control_btn").hide();
    };
    last_pwm_control = pwm_control;
	$("button").blur();
};

function check_state() {
    $.ajax({
        url: '/api/control',
        type: 'GET',
        success: function (control) {
            if (control.control.mode == 'Recipe') {
                cpMode = control.control.recipe.step_data.mode;
                cpRecipeStep = control.control.recipe.step;
                cpRecipeMode = true;
                cpRecipeStepData = control.control.recipe.step_data;
                cpRecipePause = control.control.recipe.step_data.pause;
                cpRecipeTriggered = control.control.recipe.step_data.triggered;
            } else {
                cpMode = control.control.mode;
                cpRecipeStep = 0;
                cpRecipeMode = false;
            }
            splus_state = control.control.s_plus;
            pwm_control = control.control.pwm_control;
            cp_primary_setpoint = control.control.primary_setpoint;

            // Update toolbar visibility
            if (cpRecipeMode) {
                $("#stopped_group, #startup_group, #active_group, #shutdown_group, #manual_group").hide();
				$("#recipe_group").show();
                if (cpRecipeStep != cpRecipeLastStep) {
                    update_recipe_mode();
                }
            } else {
                update_mode();
            }

            // Other updates
            if (splus_state != last_splus_state) {
                update_splus();
            }
            if (pwm_control != last_pwm_control) {
                update_pwm();
            }
            if (cp_primary_setpoint != last_primary_setpoint) {
                update_setpoint();
            }
            if (cpRecipePause != cpLastRecipePause || cpRecipeTriggered != cpLastRecipeTriggered) {
                update_recipe_pause();
            }
        }
    });
}

function check_current() {
    $.ajax({
        url : '/api/current',
        type : 'GET',
        success : function (current) {
            cp_units = current.status.units;
        }
    });
};

function cpRecipeUnpause() {
    cpRecipeStepData.pause = false;
    var postdata = {
        'recipe' : {
            'step_data' : cpRecipeStepData
        }
    };
    api_post(postdata);
    cpRecipePause = false;
    update_recipe_pause();
};

function cpStartupCheck(enable) {
    if (enable == 'False') {
        cpStartup();
    } else {
        $('#startupModal').modal('show');
    };
};

function cpStartup() {
    $('#startupModal').modal('hide');
    var postdata = { 
        'updated' : true,
        'mode' : 'Startup'	
    };
    console.log('Requesting Startup.');
    api_post(postdata);
};

function cpShutdown() {
    var postdata = { 
        'updated' : true,
        'mode' : 'Shutdown'	
    };
    console.log('Requesting Shutdown.');
    api_post(postdata);
};

function cpStopCheck(enable) {
    if (enable == 'False') {
        cpStop();
    } else {
        $('#stopModal').modal('show');
    };
};

function cpStop() {
    $('#stopModal').modal('hide');
    var postdata = { 
        'updated' : true,
        'mode' : 'Stop'	
    };
    console.log('Requesting Stop.');
    api_post(postdata);
};

function cpManualCheck(enable) {
    if (enable == 'False') {
        cpManual();
    } else {
        $('#manualModal').modal('show');
    };
};

function cpManual() {
    $('#manualModal').modal('hide');
    var postdata = { 
        'updated' : true,
        'mode' : 'Manual'	
    };
	
    console.log('Requesting Manual Mode.');
    api_post(postdata);
	updateButtonStyle();
};

// Main Loop
$(document).ready(function(){
    check_current();
	updateButtonStyle();
    
    // Setup Button Listeners
    $('#startupModal').on('shown.bs.modal', function (event) {
        $('#startupSlider').val(0);
    });

    // Add listener for setpointModal to auto-select text
    $('#setpointModal').on('shown.bs.modal', function () {
        var input = document.getElementById('tempOutputId');
        if (input) {
            input.focus();
            input.select();
        }
    });

    $("#monitor_btn").click(function(){
        var postdata = { 
            'updated' : true,
            'mode' : 'Monitor'	
        };
        console.log('Requesting Monitor.');
        api_post(postdata);
    });

    $("#shutdown_active_btn, #cp_recipe_shutdown_btn").click(function(){
        cpShutdownCheck('True');
    });

    $("#stop_active_btn, #stop_inactive_btn").click(function(){
        cpStopCheck('True');
    });

    $("#smoke_inactive_btn, #smoke_active_btn").click(function(){
        var postdata = { 
            'updated' : true,
            'mode' : 'Smoke'
        };
        console.log('Requesting Smoke.');
        api_post(postdata);
    });

    $("#splus_btn").click(function(){
        if(splus_state == true) {
            var postdata = { 's_plus' : false };
            console.log('splus_state = ' + splus_state + ' Requesting false.');
        } else {
            var postdata = { 's_plus' : true };
            console.log('splus_state = ' + splus_state + ' Requesting true.');
        };
        api_post(postdata);
    });

    $("#pwm_control_btn").click(function(){
        if(pwm_control == true) {
            var postdata = { 'pwm_control' : false };
            console.log('pwm_control_state = ' + pwm_control + ' Requesting false.');
        } else {
            var postdata = { 'pwm_control' : true };
            console.log('pwm_control_state = ' + pwm_control + ' Requesting true.');
        };
        api_post(postdata);
    });

    $("#hold_modal_btn").click(function(){
        var setPoint = parseInt($("#tempInputId").val());
        var postdata = { 
            'updated' : true,
            'mode' : 'Hold',
            'primary_setpoint' : setPoint 
        };
        console.log('Requesting Hold at: ' + setPoint);
        api_post(postdata);
    });

    $("#cp_recipe_next_step_btn").click(function(){
        if(cpRecipePause && cpRecipeTriggered) {
            console.log('Unpausing to Next Step.');
            cpRecipeUnpause();
        } else {
            console.log('Requesting Next Step.');
            var postdata = { 
                'updated' : true
            };
            api_post(postdata);
        };
    });

    // Control Panel Loop
    setInterval(function(){
        check_state();
    }, 500); // Update every 500ms 
});