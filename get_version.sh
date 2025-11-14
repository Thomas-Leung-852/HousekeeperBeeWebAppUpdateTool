#!/bin/bash
ver=$(curl -s -L "https://drive.google.com/uc?export=download&id=1u_jXIKHBDScf-2XHuoybkJ4XxPLyk9wd" | jq -r '.version')
echo $ver
