const https = require('https');

exports.handler = async function (event) {
    console.log(JSON.stringify(event, null, 2));

    // Check if event.Records exists and has elements
    if (event.Records && event.Records.length > 0) {
        console.log('From SNS:', event.Records[0].Sns.Message);

        const message = event.Records[0].Sns.Message;

        const postData = JSON.stringify({
            "text": message
        });

        const options = {
            method: 'POST',
            hostname: 'chat.googleapis.com',
            port: 443,
            path: process.env.CHAT_API_PATH,
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData)
            }
        };

        try {
            await sendRequest(options, postData);
            return { statusCode: 200, body: 'Message sent successfully' };
        } catch (error) {
            console.log('Problem with request:', error.message);
            throw error;
        }
    } else {
        console.log('No records found in the event.');
        return { statusCode: 200, body: 'No records to process' };
    }
};

function sendRequest(options, postData) {
    return new Promise((resolve, reject) => {
        const req = https.request(options, (res) => {
            let data = '';
            res.setEncoding('utf8');
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                resolve(data);
            });
        });

        req.on('error', (error) => {
            reject(error);
        });

        req.write(postData);
        req.end();
    });
}