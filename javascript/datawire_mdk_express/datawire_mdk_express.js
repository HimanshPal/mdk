var datawire_mdk = require('datawire_mdk');
var process = require('process');

var mdk = datawire_mdk.mdk.start();
process.on('exit', function () {
    mdk.stop();
});

// Start an interaction for each request, end it when the response finishes.
exports.mdkSessionStart = function (req, res, next) {
    var header = req.get(datawire_mdk.mdk.MDK.CONTEXT_HEADER);
    if (header === undefined) {
        header = null;
    }
    req.mdk_session = mdk.join(header);
    req.mdk_session.start_interaction();
    var mdk_session = req.mdk_session;
    function endSession() {
        mdk_session.finish_interaction();
    }
    res.on("finish", endSession);
    res.on("close", endSession);
    next();
};

// Fail the interaction on errors.
exports.mdkErrorHandler = function (err, req, res, next) {
    req.mdk_session.fail_interaction(err.toString());
    next(err);
};