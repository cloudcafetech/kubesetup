#### Notes

```
HIP=`ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1`
sed -i "s/172.31.14.138/$HIP/g" *

PUB=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
sed -i "s/3.16.154.209/$PUB/g" *
```
