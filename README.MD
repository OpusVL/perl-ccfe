# Builder for ccfe

* Dockerfile.initial
    used to create buildtool with all the required initial components, in effect the builder for: 
    registry.deploy.opusvl.net/public/debian-stable-buildtool:20210111-step1
* Dockerfile.build
    used to build gcc, libtool and others to create an enviroment capable of building ncurses correctly, creates: 
    registry.deploy.opusvl.net/public/debian-stable-buildtool:20210111-step2
    

