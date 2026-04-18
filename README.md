
# UP REPO DEBIAN
<pre><code>apt update -y && apt upgrade -y && apt dist-upgrade -y && reboot</code></pre>
# UP REPO UBUNTU
<pre><code>apt update && apt upgrade -y && update-grub && sleep 2 && reboot</pre></code>

### INSTALL SCRIPT 
<pre><code>apt -y install wget curl && wget -q https://raw.githubusercontent.com/diwanbhoikfost/v2/main/main && chmod +x main && ./main
</code></pre>

### TESTED ON OS 
- UBUNTU 20,22,24,25
- DEBIAN 10,11,12,13
