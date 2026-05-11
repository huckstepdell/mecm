# Disable Sleep on AC
powercfg /change standby-timeout-ac 0

# Disable Hibernate on AC
powercfg /change hibernate-timeout-ac 0

# Turn off Hibernate Completely
powercfg /h off

# Sleep Display on AC after 10 minutes
powercfg /change monitor-timeout-ac 10
