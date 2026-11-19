
# Using ENV files in Stacks with Portainer

Source: https://www.portainer.io/blog/using-env-files-in-stacks-with-portainer

Note: The following only applies to Docker Standalone and does not work for Docker Swarm.

OK, so a little confession.. our documentation, whilst already pretty comprehensive, doesn't cover every single detail of Portainer features... why? Because we are still a startup, and its only in the last 12 months that we have had the ability to fund people to start to focus on our documentation... so there are times when things are just, well, not documented.

We were recently called out for a particular piece of functionality in Portainer that is not documented (it will be now), in regards to using ENV files when deploying Stacks with Portainer. As a way to first apologize to the reporter (and to thank you for highlighting the missing docs), and to start the process to get this documented, I figured a blog would make sense.. so here goes.

So, you have a compose/stack file that has a lot of environment variables, and you want to load these into Portainer via an ENV file, and then make these available to the stack as a file (negating the need to define each one manually). How do you do that?

Well there is a nifty little button in Portainer "load variables from env file", and if you click that button, and select a ENV file on your PC, we auto-populate Portainer with these variables.

Cool, but how do you actually use them in your stack?

Well this where the documentation issue arises... we don't actually mention anywhere how to use these as a file... so you would naturally think that you need to reference these one by one, such as below:

and this would work... as shown in the resulting deployment.

But that's annoying.. what about just referring to the values as a file.. an ENV file even..

Well, you just need to reference the env file we create in the service definition. We call the file "stack.env" and it contains all of the variables read in from the external env file.

and that auto-creates the variables in the container without you having to manually enter them in via Portainer or 1:1 in the stack definition.

OK but that specifies a singular ENV file, how do I use that with multiple services in a stack?

well, you need a ENV file that contains all of the variables your stack needs; take this example..

then in Portainer, you use the "load from file" which loads them into the stacks page like so..

and then you reference them in your stack file like so..

But be aware, the ENVs are populated to BOTH of the services as they share a single file. This may cause you concern (or not).

So, this is how you use an external ENV file with Portainer Stacks.. expect to see this in the docs very soon.

Oh, and if you find features that are undocumented (or not clearly documented), please let us know.

Try Portainer with 3 Nodes Free

If you're ready to get started with Portainer Business, 3 nodes free is a great place to begin. If you'd prefer to get in touch with us, we'd love to hear from you!

Neil Cresswell