/**
 * Created by enukane on 2016/07/21.
 */

var _demo_ = false;

/* common utility */

function log_debug(msg) {
    console.info("[DEBUG] " + msg);
}

function log_warn(msg) {
    console.warn("[WARNING] " + msg);
}

function log_cmd(msg) {
    console.log("[CMD] " + msg);
}

function log_cmdresult(msg) {
    console.log("[CMD-RESULT] " + msg);
}

function log_periodic(msg) {
    console.log("[PERIODIC] " + msg);
}

function bytes_to_h(bytes) {
    kb = bytes / 1000.0;
    mb = bytes / (1000.0 * 1000.0);
    gb = bytes / (1000.0 * 1000.0 * 1000.0);

    var hfmt = "";
    if (gb >= 1.0) {
        hfmt = gb.toFixed(2) + " GB";
    } else if (mb >= 1.0) {
        hfmt = mb.toFixed(2) + " MB";
    } else {
        hfmt = kb.toFixed(2) + " KB";
    }

    return hfmt
}

function usage_to_percentage(size, used) {
    usage = used / size * 100.0;

    return usage.toFixed(2) + " %";
}

function usage_string(size, used) {
    used_bytes = bytes_to_h(used);
    usage_percent = usage_to_percentage(size, used);
    fmt = used_bytes + " (" + usage_percent + ")";

    return fmt;
}

/*
    UI Modifications
 */
/* common utilities */
function update_text(id, text) {
    $(id).text(text);
}

function disable_element(id) {
    attrs = $(id).attr("class");
    var new_attrs = attrs.replace(/disabled/, "") + " disabled";

    $(id).attr("class", new_attrs);
}

function enable_element(id) {
    attrs = $(id).attr("class");
    var new_attrs = attrs.replace(/disabled/, "");

    $(id).attr("class", new_attrs);
}

/* id specific utilities */
// state
function update_state_label(new_label, text) {
    attrs = $("#label-state").attr("class");
    var new_attrs = attrs.replace(/label-.*/, new_label);

    $("#label-state").attr("class", new_attrs);
    $("#label-state").text(text);
}

// buttons
function enable_button_start() {
    enable_element("#button-start");
}

function disable_button_start() {
    disable_element("#button-start");
}

function enable_button_stop() {
    enable_element("#button-stop");
}

function disable_button_stop() {
    disable_element("#button-stop");
}

// status string
function update_date(epoch) {
    console.log("date is now " + epoch + " " + typeof epoch);

    var date = new Date(0);
    date.setUTCSeconds(epoch);
    update_text("#dd-date", date.toLocaleString());
}

function update_hostname(hostname) {
    update_text("#dd-hostname", hostname);
}

function update_disk(size, used) {
    if (typeof size === "undefined" || typeof usage === "undefined") {
        log_warn("disk_size or disk_used is empty");
        return;
    }
    fmt = usage_string(size, used);

    update_text("#dd-disk-usage", fmt)
}

function update_memory(size, used) {
    fmt = usage_string(size, used);

    update_text("#dd-memory-usage", fmt);
}

function update_cpu(usage) {
    if (typeof usage === "undefined") {
        usage = "NaN";
    }
    fmt = usage.toFixed(2).toString() + " %";

    update_text("#dd-cpu-usage", fmt);
}


function update_file_info(name, size, duration) {
    if (typeof name === "undefined") {
        log_warn("file_name is empty");
        return;
    }
    update_text("#dd-file-name", name);

    update_text("#dd-file-size", bytes_to_h(size));

    var size_per_sec = size / duration;
    update_text("#dd-file-size-bps", bytes_to_h(size_per_sec) + "ps");
}

function update_channel_info(current, walk) {

    update_text("#dd-current-channel", current);
    update_text("#dd-channel-walk", walk);
}

function update_utilization_info(channel, utilization) {
    update_text("#dd-utilization-channel", channel);
    update_text("#dd-utilization", utilization);

    update_util_chart(channel, utilization);
}

/*
    State Handlers
*/
var STATE = {
    "INIT": "INIT",
    "STARTING":         "STARTED",
    "STARTED":          "STARTED",
    "RUNNING":          "RUNNING",
    "STOPPING":         "STOPPING",
    "STOPPED" :         "STOPPED",
    "STATUS_OK":        "STATUS OK",
    "STARTING_FAILED":  "STARTING FAILED",
    "STOPPING_FAILED":  "STOPPING FAILED",
    "STATUS_FAILED":    "STATUS FAILED",
    "UNKNOWN":          "UNKNOWN"
};
var __current_state = STATE.INIT;

function get_current_state() {
    return __current_state;
}

function update_state(state) {
    console.log("state = " + state);

    switch (state) {
        case STATE.INIT:
            update_state_label("label-default", state);
            enable_button_start();
            disable_button_stop();
            break;
        case STATE.STARTING:
            update_state_label("label-info", state);
            break;
        case STATE.STARTED:
            update_state_label("label-primary", state);
            enable_button_stop();
            break;
        case STATE.RUNNING:
            update_state_label("label-success", state);
            disable_button_start();
            enable_button_stop();
            break;
        case STATE.STOPPING:
            update_state_label("label-info", state);
            enable_button_start();
            break;
        case STATE.STOPPED:
            update_state_label("label-primary", state);
            enable_button_start();
            disable_button_stop();
            break;
        case STATE.STARTING_FAILED:
            update_state_label("label-danger", state);
            enable_button_start();
            break;
        case STATE.STOPPING_FAILED:
            update_state_label("label-danger", state);
            break;
        case STATE.STATUS_FAILED:
            update_state_label("label-warning", state);
            break;
        case STATE.UNKNOWN:
        default: /* fall throuth */
            update_state_label("label-danger", state);
            return;
            break; /* never comes here */
    }

    __current_state = state;
}

/* status */
function update_status(json) {
    /*
     * {
     *  "date":         <arbitrary date in String>,
     *  "hostname":     <hostname in String>,
     *  "disk_size":    <bytes in Int>,
     *  "disk_used":    <bytes in Int>,
     *  "memory_size":  <bytes in Int>,
     *  "memory_used":  <bytes in Int>,
     *  "cpu_usage":    <percentage in Int>,
     *  "state":        "INIT" | "RUNNING" | "STOP",
     *  "filename":     <String>,
     *  "filesize":     <bytes in Int>,
     *  "duration":     <sec in Int>,
     *  "current_channel": <channel number in Int>,
     *  "channel_walk": <count in Int>,
     *  "utilization":  <percentage in Int>,
     *  "utilization_channel": <channel number in Int>,
     * }
     */

    console.log(json);
    console.log(json["date"]);
    console.log(typeof json["date"]);
    // update date
    update_date(json.date);

    // update hostname
    update_hostname(json["hostname"]);

    // update disk
    update_disk(json["disk_size"], json["disk_used"])

    // update memory
    update_memory(json["memory_size"], json["memory_used"]);

    // update cpu
    update_cpu(json["cpu_usage"]);

    // update state
    var new_state = STATE.INIT;
    switch(json["state"]) {
        case "INIT":
            break;
        case "RUNNING":
            new_state = STATE.RUNNING;
            break;
        case "STOP":
            new_state = STATE.STOPPED;
            break;
        case "INIT":
        default: /* fall through */
            new_state = STATE.INIT;
            break;
    }
    update_state(new_state);

    update_file_info(json["filename"], json["filesize"], json["duration"]);

    update_channel_info(json["current_channel"], json["channel_walk"]);
    update_utilization_info(json["utilization_channel"], json["utilization"]);
}

/* periodic worker */

(function worker() {
    $.ajax({
        type: "get",
        url: '/api/v1/status',
        contentType: 'application/json',
        dataType: "json",
        success: function(json) {
            log_periodic("success > " + JSON.stringify(json));
            update_status(json);
        },
        error: function() {
            log_periodic("error");
            update_state(STATE.STATUS_FAILED);
        },
        complete: function() {
            log_periodic("schedule next");
            setTimeout(worker, 500);

            if (_demo_ == true) {
                update_util_chart(Math.ceil(Math.random() * 100) , Math.random() * 100);
            }
        }
    });
})();

/*
    UI Event Handlers
 */
$("#button-start").on('click', function (e) {
    log_cmd("starting capture");
    update_state(STATE.STARTING);
    $.ajax({
        type: "post",
        url: "/api/v1/start",
        data: JSON.stringify({method: "godoit"}),
        contentType: 'application/json',
        dataType: "json",
        success: function (json) {
            log_cmdresult("starting success");
            update_state(STATE.STARTED);
        },
        error: function () {
            log_cmdresult("starting failed");
            update_state(STATE.STARTING_FAILED);
        },
        complete: function() {
            log_cmdresult("starting complete");
        }
    });
});

$("#button-stop").on('click', function (e) {
    log_cmd("stopping capture");
    update_state(STATE.STOPPING);
    $.ajax({
        type: "post",
        url: "/api/v1/stop",
        success: function (json) {
            log_cmdresult("stopping success");
            update_state(STATE.STOPPED);
        },
        error: function () {
            log_cmdresult("stopping failed");
            update_state(STATE.STOPPING_FAILED)
        },
        complete: function() {
            log_cmdresult("stopping complete");
        }
    })
});

var _util_table = [
    // 2.4GHz
    {label: "1", y: 0},
    {label: "2", y: 0},
    {label: "3", y: 0},
    {label: "4", y: 0},
    {label: "5", y: 0},
    {label: "6", y: 0},
    {label: "7", y: 0},
    {label: "8", y: 0},
    {label: "9", y: 0},
    {label: "10", y: 0},
    {label: "11", y: 0},
    {label: "12", y: 0},
    {label: "13", y: 0},

    // 5.2GHz
    {label: "34", y: 0},
    {label: "36", y: 0},
    {label: "38", y: 0},
    {label: "40", y: 0},
    {label: "42", y: 0},
    {label: "44", y: 0},
    {label: "46", y: 0},
    {label: "48", y: 0},

    // 5.3GHz
    {label: "52", y: 0},
    {label: "56", y: 0},
    {label: "60", y: 0},
    {label: "64", y: 0},

    // 5.6GHz
    {label: "100", y: 0},
    {label: "104", y: 0},
    {label: "108", y: 0},
    {label: "112", y: 0},
    {label: "116", y: 0},
    {label: "120", y: 0},
    {label: "124", y: 0},
    {label: "128", y: 0},
    {label: "132", y: 0},
    {label: "136", y: 0},
    {label: "140", y: 0},
    {label: "144", y: 0},
    {label: "149", y: 0},
    {label: "153", y: 0},
    {label: "157", y: 0},
    {label: "161", y: 0},
    {label: "165", y: 0},
];

var COLOR_GRADE = {
    "RED": 90,
    "ORANGE": 70,
    "YELLOW": 50,
    "GREEN": 0
};

var _util_chart = null;

$(window).load("load", function() {
    _util_chart = new CanvasJS.Chart("utilChartContainer", {
        animationEnabled: true,
        axisX: {
            interval: 1,
            gridThickness: 0,
            labelFontSize: 15,
            labelFontStyle: "normal",
            labelFontWeight: "normal",
        },
        axisY: {
            interlacedColor: "rgba(1.77,101,.2",
            gridColor: "rgba(1.77,101,.1)",
            minimum: 0,
            maximum: 100
        },
        data: [
            {
                type: "column",
                name: "utilization",
                //axisYType: "secondary",
                color: "#014D65",
                dataPoints: _util_table
            }
        ]
    });

    _util_chart.render();
});

function update_util_chart(chan, util) {
    if (chan == null) {
        return;
    }
    chan_str = chan.toString();

    color =
        util >= COLOR_GRADE["RED"] ? "#FF0000" :
        util >= COLOR_GRADE["ORANGE"] ? "#FFA500" :
        util >= COLOR_GRADE["YELLOW"] ? "#FFd700" :
        "#008000";

    var idx = -1;

    for (var i = 0; i < _util_table.length; i++) {
        if (_util_table[i].label == chan_str) {
            console.log("found at " + i);
            idx = i;
            _util_table[i].y = util;
            _util_table[i].color = color;
            break;
        }
    }

    if (idx == -1) {
        log_warn("could not find utiltable entry in channel " + chan_str);
        return;
    }

    if (_util_chart == null) {
        return;
    }

    _util_chart.render();
}


/* init */
update_state(STATE.INIT);