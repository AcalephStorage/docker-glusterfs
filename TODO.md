TODO:
------------

- Currently it is using host based networking. Try to find a way to avoid this and maybe connect to fellow glusterfs pods through flannel.
- Check if possible not to use `privileged=true` as this will allow capabilities almost the same as with the parent node.
- Update docs
- Housekeeping
- Proper error handling and checkings
 
