# GodotAWSAnalytics
A collection of client and server code that can be used to add AWS Mobile Analytics to your Godot 3.x game

## Features
* No special Godot modules required
* Supports iOS, Android, Amazon Fire, WebGL, Windows, Mac, and Linux

## Instructions

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
