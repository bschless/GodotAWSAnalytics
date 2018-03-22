# GodotAWSAnalytics
A collection of client and server code that can be used to add AWS Mobile Analytics to your Godot 3.x game

![alt text](https://godotengine.org/storage/app/uploads/public/5a6/3ae/e17/5a63aee174d80543898745.png "Godot Engine 3")

![alt text](http://d0.awsstatic.com/screenshots/amazon-mobile-analytics/amazon-mobile-analytics-report-screenshot-new.png "AWS Mobile Analytics sample data")

## Features
* No special Godot modules required
* Supports iOS, Android, Amazon Fire, WebGL, Windows, Mac, and Linux

## Missing Features
* Support for Monetization Events

## Roadmap
* Full Pinpoint support including push notifications

## Requirements
* Access to a console/terminal with NodeJS
* A Godot installation that has been setup to work with SSL: http://docs.godotengine.org/en/3.0/tutorials/networking/ssl_certificates.html

## Instructions

### Phase 1: Create App Within AWS Mobile Hub

The first thing you'll want to do is create a new app inside the AWS Mobile Hub within your Amazon web console.
![alt text](https://user-images.githubusercontent.com/255001/37718579-435fd842-2ce0-11e8-956a-37b81bf7d53b.PNG "Create a new app inside the AWS Mobile Hub")

Give your app an appropriate title.

![alt text](https://user-images.githubusercontent.com/255001/37718797-c740d5f8-2ce0-11e8-85ae-dfe4e87ebb96.PNG "Give your app a name")

Select a platform for your app. Make sure you select either iOS or Android, it doesn't matter which one you pick -- our game will work with both of them and more. It's job is mostly to tell AWS Mobile Hub which type of projects to generate source-code for, but we aren't using any of their generated code.

![alt text](https://user-images.githubusercontent.com/255001/37719019-4a7be14c-2ce1-11e8-8902-573bae057bda.PNG "Select a platform")

You can just click "Next" on the next step. We don't need to do anything with the cloud configuration file.

![alt text](https://user-images.githubusercontent.com/255001/37719186-ac2301f0-2ce1-11e8-858e-a9322cf3b6ae.PNG "Skip cloud configuration")

On the last step, just click "Done". We won't be integrating the AWS Mobile SDK into our game since it doesn't exist for the Godot platform.

![alt text](https://user-images.githubusercontent.com/255001/37719317-f9f031dc-2ce1-11e8-8eb6-a7276a2355a1.PNG "App creation is complete")

Once the app has been created, you will be taken to a page where you can see which backend services have been enabled for the app. By default, the only backend service that's enabled is Analytics, which is what we need.

At this point, AWS has automatically created a few resources we will need to make use of analytics, including:

* A Federated Identity Pool which will be used to assign the players of the game a unique ID.
* An IAM Role that gives our players permission to make calls to the Analytics API
* A new app entry in Mobile Analytics for this app (as well as one in Pinpoint)

Verify that these resources were created.
* The Federated User Pool should have a name similar to "mygodotgame_MOBILEHUB_1825323477"
* The IAM Role should have a similar name to "mygodotgame_unauth_MOBILEHUB_1825323477"
* The Mobile Analytics/Pinpoint dashboards should now list an app with a name simlar to "mygodotgame_MobileHub"

### Phase 2: Create Lambda Function to Parse Analytics Events

Using Amazon's own Rest API's generally require that all reqeusts be signed using Amazon's Signature V4 method: https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html

Due to the fact that the Godot engine does not include a Crypto library, and also due to the fact that I personally lack the chops to build the needed crypto libs in gdscript myself, we will need to use a custom HTTPS endpoint that we will send event data to. This endpoint will forward the event data over to a Lambda function, which will take this data and make the call to the AWS Mobile Analytics API using the AWS SDK, which automatically signs requests with Signature v4.

So, the next step then, is to set up the Lambda function that will be in charge of parsing our events and making the calls to Mobile Analytics. These instructions make use of a wonderful NodeJS library called Claudia, which we will use to create and upload our Lambda function to AWS for us. Without Claudia, we would have to manually zip up our Lambda code and its dependencies, then upload the zip file to AWS through the AWS console, which can be laborous.

Navigate to where you cloned this branch, and go into the Lambda folder. In a terminal window, run this command:

``` npm install ```

This will install the necessary node modules for the Lambda function, including our deployment tool Claudia. Once this is done, upload the Lambda function to AWS using the following command:

`` npm run create ``

This will create a new Lambda function in our AWS account and configure it for us using Claudia. Once this is complete, you should see output similar to this:

![alt text](https://user-images.githubusercontent.com/255001/37724440-03ef08aa-2cee-11e8-85e9-a9318bcf8d20.PNG "Lambda function creation success results")

This informs us that Claudia successfully created a new Lambda function in the us-east-1 region called "godot-analytics-parser" and assigned it the role "godot-analytics-parser-executor". Essentially, this was a success. 

Once the Lambda function has been created, we need to get the ARN for it for the next phase. You can get the ARN for the function by navigating to the Lambda dashboard in AWS (make sure you're in the correct region). Then, click on the name of the new function to be taken to the function's profile page. From here, make note of the ARN, which can be found in the upper-right corner. 

In this example, the function ARN is the string `arn:aws:lambda:us-east-1:123456789123:function:godot-analytics-parser`

![alt text](https://user-images.githubusercontent.com/255001/37725148-85906038-2cef-11e8-8fee-3fe9eb613ba5.PNG "Take note of the ARN for the Lambda function")

### Phase 3: Create API Gateway and Connect to Lambda Function

Next, we're going to go about creating an HTTPS endpoint that we can call from our game. We will send our analytics data to this endpoint. In turn, the endpoint will forward the data over to our Lambda function.

Before creating an API inside API Gateway, you need to make a small modification to the Swagger document in this repo. Open up the file called swagger-apigateway.json. Find the text that says {your-function-arn-here}, and replace it with the actual ARN of the function from the previous phase, then save the file.

Now, go ahead and create a new API in the API Gateway web console.

![alt text](https://user-images.githubusercontent.com/255001/37734737-3ec9f26c-2d09-11e8-8e98-19ad0380a861.PNG "Create a new API inside the API Gateway console")

After clicking "Create API", you will be asked whether or not you want to import a Swagger file. Select the "Import from Swagger" option, then click the button that says "Select Swagger File" and select the swagger file. You should see something similar to the screenshot below.

![alt text](https://user-images.githubusercontent.com/255001/37735000-092bfadc-2d0a-11e8-9e9a-9ac03568f19d.PNG "Import API from Swagger Document")

If you want great performance around the world at a slightly higher price, you can set the Endpoint Type to be "Edge Optimized". Doing this will create endpoints for your API in various Regions throughout the world, for quicker access to users who live in those regions. You can also just leave it as "Regional", which simply creates a single location for your endpoint in the same Region that the API is created in (us-east-1 in our case), but doing so will mean that users who are accessing your API from a different region than where your API is hosted will have higher latency. This may or may not end up being that important to you.

Go ahead and click on the "Import" button, and your API should be created inside the console.

![alt text](https://user-images.githubusercontent.com/255001/37735629-dfdd85d6-2d0b-11e8-84ec-2393ddb7ccdc.PNG "Finalize the import")

At this point, our api has been imported, but not deployed yet. Additionally, while our "analytics" endpoint has been set up to integrate with our Lambda function, it has not yet been granted permission to actually invoke it yet.

To give the API permission to call the Lambda function, click on the POST method of the "/analytics" resource in the Resources pane, then click "Integration Request."

![alt text](https://user-images.githubusercontent.com/255001/37738493-69da9dc0-2d14-11e8-8f04-dfa26b4f2528.PNG "Edit Integration Request Settings")

Within the Integration Request settings, click the pencil next to the name of the Lambda function. Then, simply click the checkmark that just appeared. You will be prompted to grant the API permission to invoke the Lambda function. Click OK.

![alt text](https://user-images.githubusercontent.com/255001/37738664-e63f432a-2d14-11e8-88f1-3b1d29050f95.PNG "Click the pencil next to the Lambda function name")
---
![alt text](https://user-images.githubusercontent.com/255001/37738680-f3594c36-2d14-11e8-9adc-15de7cd584af.PNG "Click the checkmark that just appeared")
---
![alt text](https://user-images.githubusercontent.com/255001/37738683-f614c888-2d14-11e8-9f91-0fdcd0f0fbe0.PNG "Click OK to grant permission")

Now that the API has permission to invoke the Lambda function, it's ready to be deployed. In the Resources pane, click the Action button, then click "Deploy API"

![alt text](https://user-images.githubusercontent.com/255001/37738966-ec0b5b08-2d15-11e8-988f-0cf41b065972.PNG "Click 'Deploy API' in the drop-down menu that appears when you click the 'Action' button")

APIs get deployed to a stage. Since there aren't any stages yet, you will be asked to create a new one. The example uses "latest" as the stage name. You can also provide a description if you want. When you're ready, click "Deploy."

![alt text](https://user-images.githubusercontent.com/255001/37738978-f0cffad6-2d15-11e8-89da-d9110ec8ca95.PNG "Give the stage a name and click Deploy")

Once the API is deployed, click the "Stages" link in the left sidebar, then click on the "latest" stage. Take note of the Invoke URL, you will need this in the next phase.

![alt text](https://user-images.githubusercontent.com/255001/37738980-f3aa17fa-2d15-11e8-8dcf-f3a243ef4b38.PNG "Click 'Stages', then click 'Latest', and take note of the Invoke URL")

### Phase 4: Integrate With Godot

To get this all integrated with your Godot game, create a new Node in your main scene of the plain "Node" type called Analytics. Then attach the script from this repo called "Analytics.gd" to this node. Once you've done that, inspect the Node and fill out the values accordingly. You will need:

1) The Federated Identity Pool Id. You can find this by going to the Cognito dashboard in the AWS console, click "Manage Federated Identities", click the name of your identity pool, then find the identity pool id in the URL bar of the web browser. Or click "Edit identity pool" at the top right. The identity pool id will look something like `us-east-1:df6fa3ce-c781-4b4d-b3z4-8f779af8dd90`.
2) Your AWS account id. Find this by clicking on your name, then "My Account in most AWS console pages.
3) The app id for the app. Find this by going to the Pinpoint dashboard. You should see your app listed along with its app id.
4) The api endpoint. This is the Ivoke URL from the last phase, plus "/analytics". So the full api endpoint would be similar to `https://ye3fl59dvk.execute-api.us-east-1.amazonaws.com/latest/analytics`.

Optionally, you can provide the following values in the inspector:
* App Package Name - the package name used for your game, whatever you've decided it should be
* App Title - The name of your game
* Api Key - If you've done some extra work and secured the api with an api key, provide that key here
* App Version Name - Can be anything, usually something like "1.0.0"
* App Version Code - The number of versions that have ever been created, like 42 or how many have ever been created

#### Sessions

A session will start automatically when the app starts, and will end in one of two ways: Either when the app is closed, or when the app has been sent to the background for more than five seconds (a new session will start when the user comes back).

#### Recording Events

Once you've attached the script to the node and filled out the values in the inspector, you're ready to start recording events. To record an event, get a reference to the node with something like `var analytics = get_node('Analytics')`. Then call the record_event function like this: `analytics.record_event('My Event')`

You can also include attributes and metrics in your event like this: `analytics.record_event('Collect Coin', {world = 'grasslands'}, {coin_value = 50})`

After about an hour, you should start seeing session and event data within the Mobile Analytics console.
