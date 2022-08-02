#########################################################################################
# SCENARIO 3: Update Grafana & navigate through Prometheus and Grafana
#########################################################################################

**GOAL:**  
This lab is already equipped with Prometheus & Grafana, which were installed with Helm.  
However, to complete this scenario, we will modify the current configuration.  

We will then first upgrade the Prometheus operator, & then see how to connect & use both Prometheus and Grafana.  
Finally, if you are using NetApp Harvest to collect data from ONTAP, we will see how to integrate Harvest into Prometheus.  

The scenario has been divided in 4 steps:

- [Upgrade](1_Upgrade): Upgrade the Prometheus Operator
- [Prometheus](2_Prometheus): Navigate through Prometheus
- [Grafana](3_Grafana): Configure & use Grafana
- [Harvest](4_Harvest): Integrating with NetApp Harvest
