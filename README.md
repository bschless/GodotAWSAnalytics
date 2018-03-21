# GodotAWSAnalytics
A collection of client and server code that can be used to add AWS Mobile Analytics to your Godot 3.x game

## Features
* No special Godot modules required
* Supports iOS, Android, Amazon Fire, WebGL, Windows, Mac, and Linux

## Requirements
* Access to a console/terminal with NodeJS

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
