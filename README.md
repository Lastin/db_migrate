# Database migration script exercise

The answer is contained in `script.sh`

Script can be run with:
`./script.sh ./scripts mysql_host mysql_user mysql_password`

Alternatively can be run within docker through Makefile (for faster and contained testing):
1. Run `make reset` - resets the container and bootstraps the database
1. Run `docker-compose ps` to check the container is healthy and ready
1. Runn `make run` - executes the script within the container
