var page = new WebPage(), address, mode, output;

var screenshot_counter = 1;
var system = require('system');
var fs = require('fs');
var args = system.args;

if (args.length < 2) {
        console.log('Wrong args (expected: address), got: ', args);
        phantom.exit("01");
} else {
    address = args[1];
    output = args[2];

    // Clear output directory
//    fs.removeTree(output);
//    fs.makeDirectory(output);

    if (address.substr(0,1)!='h') address = "file:///"+ address;
    page.open(address);

    var code = '14';
    var console_log = [];

    page.onError = function(msg, trace) {
        console.error('ERROR', msg, JSON.stringify(trace));
        phantom.exit("13")
    };

    page.onConsoleMessage = function(msg) {
        if (msg == 'exit') phantom.exit("13");
        console.log(msg)
    };
}