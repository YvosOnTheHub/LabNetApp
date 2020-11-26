#########################################################################################
# ADDENDA 7: Install K8SH
#########################################################################################

I found K8SH to be pretty useful, as it allows to easily navigate through your favorite kubectl commands without explicitly write the namespace all the time.  
Also, it tells in in which context you are, which can also be good to have.  

More information here: https://github.com/Comcast/k8sh  
You will find there:

- how to install this shell
- how to manage contexts & namespaces
- all the available shortcuts (ex: _pods_ stands for _kubectl get pods_)  

To accomodate the current Putty configuration, we also need to change some colors.  

```bash
cd
git clone https://github.com/Comcast/k8sh.git
mv k8sh/k8sh /usr/bin/
sed -e '/  NAMESPACE_COLOR.*/ s/CYAN/BLUE/' -i /usr/bin/k8sh
sed -e '/  PS_NAMESPACE_COLOR.*/ s/CYAN/BLUE/' -i /usr/bin/k8sh
sed -e '/  PS_CONTEXT_COLOR.*/ s/LRED/RESTORE/' -i /usr/bin/k8sh
```
