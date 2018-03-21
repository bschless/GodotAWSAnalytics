const AWS = require('aws-sdk')

exports.handler = (event, context, callback) => {
    var sessionObj = JSON.parse(event.session)
    var attributes = JSON.parse(event.attributes)
    var metrics = JSON.parse(event.metrics)
    var clientContext = JSON.parse(event.clientContext)
    var analytics = new AWS.MobileAnalytics({
        accessKeyId: event.accessKeyId,
        secretAccessKey: event.secretAccessKey,
        sessionToken: event.sessionToken,
    })
    var params = {
        clientContext: JSON.stringify(clientContext),
        events: [
            {
                eventType: event.eventType,
                timestamp: event.timestamp,
                attributes: attributes,
                metrics: metrics,
                session: sessionObj,
                version: "2.0"
            }
        ],
        clientContextEncoding: "application/json"
    }
    analytics.putEvents(params, (err, data) => {
        if (err) {
            callback(err)
        }
        else if (data) {
            callback(null, JSON.stringify(data))
        }
    })
}