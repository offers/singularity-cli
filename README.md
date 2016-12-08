# singularity-cli
Authors: 
    @traviswdev
    @chriskite

# Testing:
./test.sh

# Usage:
singularity deploy <uri> <file.json> <release>
    - deploy singularity job

singularity delete <uri> <file.json>
    - delete singularity deploy

singularity run <commands>
    - start new box in singularity and run <commands>
      (do this from the base project folder of the box you wish to start)

singularity runx <commands>
    - same as "singularity run" without use of /sbin/my_init
    
singularity ssh
    - start new box in singularity and SSH into it
