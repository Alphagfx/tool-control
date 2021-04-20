# tool-control
Bash script for subscribing to a custom tool

The purpose of this bash script is to control your custom tool state, updating it on certain conditions:
1. The tool should be running only if there are active subscribers
   1. The tool should not be running if there are no subscribers
1. Check subscribers regularly and update their status according to theirs expiration timeout

TODO:
 - [ ] It should be safe to execute this script concurrently
