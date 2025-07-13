# Linux Post Install Scripts

Set of scripts to setup server and workstation Linux distributions to my needs.

Many things are deprecated, use at your own risks.

Basic usage : Execute the setup wrapper with proper arguments from URL:
```sh
URL="https://raw.githubusercontent.com/antoine-morvan/linux_postinstall/refs/heads/master/setup.sh"
URL="https://tinyurl.com/38x8e73f"
URL="https://urlr.me/8Nm2bZ"
bash <(curl -L -s $URL) $ARGS
```

if needed, add the following flags to curl to disable cache : 
```sh
# Taken from https://reqbin.com/req/c-dyugjcgf/curl-no-cache-example
# -H "Cache-Control: no-cache, no-store, must-revalidate"
# -H "Pragma: no-cache"
# -H "Expires: 0"
bash <(curl -H "Cache-Control: no-cache, no-store, must-revalidate" -H "Pragma: no-cache" -H "Expires: 0" -L -s $URL) $ARGS
```
