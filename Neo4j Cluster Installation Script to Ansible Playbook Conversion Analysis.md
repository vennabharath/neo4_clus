# Neo4j Cluster Installation Script to Ansible Playbook Conversion Analysis

This document details the analysis of the provided `install_neo4j_cluster.sh` shell script, extracting key information necessary for its conversion into an Ansible playbook. The goal is to identify all components, configurations, and logic that need to be translated into Ansible tasks, variables, and templates.

## Phase 1: Analyze Shell Script and Extract Key Information

### 1.1 Variables and their Default Values

The shell script defines several configuration variables at the beginning. These will be translated into Ansible variables, likely within a `vars` section or `group_vars`/`host_vars` files.

| Variable Name          | Default Value      | Description                                     |
|------------------------|--------------------|-------------------------------------------------|
| `NEO4J_VERSION`        | `5.15.0`           | Version of Neo4j to install                     |
| `NEO4J_HOME`           | `/opt/neo4j`       | Installation directory for Neo4j                |
| `NEO4J_USER`           | `neo4j`            | System user for Neo4j                           |
| `NEO4J_GROUP`          | `neo4j`            | System group for Neo4j                          |
| `CLUSTER_NAME`         | `neo4j-cluster`    | Name of the Neo4j cluster                       |
| `INITIAL_PASSWORD`     | `neo4j-admin`      | Initial password for Neo4j admin user           |
| `CORE_PORT_BASE`       | `7687`             | Base port for Bolt protocol on core servers     |
| `READ_REPLICA_PORT_BASE`| `8687`            | Base port for Bolt protocol on read replica servers |
| `HTTP_PORT_BASE`       | `7474`             | Base port for HTTP connector                    |
| `HTTPS_PORT_BASE`      | `7473`             | Base port for HTTPS connector                   |
| `BACKUP_PORT_BASE`     | `6362`             | Base port for backup                            |
| `CLUSTER_PORT_BASE`    | `5000`             | Base port for cluster communication             |
| `RAFT_PORT_BASE`       | `7000`             | Base port for Raft protocol                     |

### 1.2 Shell Script Functions to Ansible Modules/Tasks Mapping

The shell script is structured into several functions, each performing a specific set of operations. These functions will be mapped to corresponding Ansible tasks or roles.

| Shell Function Name        | Description                                     | Corresponding Ansible Approach |
|----------------------------|-------------------------------------------------|--------------------------------|
| `check_root`               | Checks if the script is run as root.            | Ansible `become` and user checks |
| `validate_input`           | Validates command-line arguments.               | Ansible playbook variables and validation |
| `detect_os`                | Detects OS and package manager.                 | Ansible `ansible_distribution` and `ansible_pkg_mgr` facts |
| `install_java`             | Installs Java 17.                               | `ansible.builtin.apt` or `ansible.builtin.yum` module |
| `create_neo4j_user`        | Creates Neo4j user and group.                   | `ansible.builtin.group` and `ansible.builtin.user` modules |
| `install_neo4j`            | Downloads and installs Neo4j.                   | `ansible.builtin.get_url`, `ansible.builtin.unarchive`, `ansible.builtin.file` modules |
| `configure_firewall`       | Configures firewall rules (UFW/Firewalld).      | `community.general.ufw` or `ansible.posix.firewalld` modules |
| `get_server_ip`            | Gets the server's primary IP address.           | Ansible facts (`ansible_default_ipv4.address`) |
| `generate_core_config`     | Generates `neo4j.conf` for core servers.        | Jinja2 template for `neo4j.conf` |
| `generate_replica_config`  | Generates `neo4j.conf` for read replicas.       | Jinja2 template for `neo4j.conf` |
| `generate_discovery_members`| Generates discovery members list.               | Jinja2 template logic or custom filter |
| `create_systemd_service`   | Creates and enables systemd service for Neo4j.  | `ansible.builtin.systemd` and Jinja2 template for service file |
| `set_initial_password`     | Sets initial Neo4j password.                    | `ansible.builtin.command` or `ansible.builtin.shell` module |
| `create_monitoring_script` | Creates monitoring script and crontab entry.    | Jinja2 template for script, `ansible.builtin.cron` module |
| `display_cluster_info`     | Displays cluster information.                   | Ansible `debug` module or `ansible.builtin.template` for summary file |
| `main`                     | Main execution logic.                           | Overall Ansible playbook structure and task execution order |

### 1.3 Conditional Logic and Loops

The script uses `if/else` statements for OS detection, input validation, and checking existing installations. It also uses `for` loops for firewall port ranges and generating discovery members.

- **OS Detection:** Handled by Ansible facts (`ansible_distribution`, `ansible_pkg_mgr`).
- **Input Validation:** Can be managed by defining variable types and requirements in Ansible, or by using `assert` tasks.
- **Existing Installations:** Ansible modules are generally idempotent, meaning they only make changes if necessary, thus handling existing installations implicitly.
- **Firewall Port Ranges:** Can be handled with `loop` or `with_items` in Ansible tasks.
- **Discovery Members Generation:** Requires Jinja2 templating logic within the `neo4j.conf` template.

### 1.4 External Dependencies

The script relies on several external commands and packages:

- `java`: Java Development Kit (JDK) version 17.
- `wget`: Used for downloading the Neo4j package.
- `curl`: Used in the monitoring script for health checks.
- `systemctl`: For managing systemd services.
- `ufw`: Ubuntu/Debian firewall management.
- `firewall-cmd`: RHEL/CentOS firewall management.
- `awk`, `cut`, `grep`, `hostname`, `ip`: Standard Linux utilities for text processing and network information.

Ansible will handle these dependencies by ensuring the necessary packages are installed and commands are available on the target systems.

### 1.5 File System Operations

The script performs various file system operations:

- `mkdir -p`: Creating directories (`/opt/neo4j`).
- `tar -xzf`: Extracting the Neo4j archive.
- `mv`: Moving extracted Neo4j directory.
- `chown -R`: Changing ownership of Neo4j directory.
- `chmod -R`: Changing permissions of Neo4j directory.
- `ln -sf`: Creating symbolic links (`/usr/local/bin/neo4j`, `/usr/local/bin/neo4j-admin`).
- `tee`, `cat >`: Writing configuration files (`neo4j.conf`, `neo4j.service`, `cluster_monitor.sh`).

Ansible modules like `ansible.builtin.file`, `ansible.builtin.unarchive`, `ansible.builtin.copy`, and `ansible.builtin.template` will be used for these operations.

### 1.6 User and Group Management

The script creates a `neo4j` user and group:

- `groupadd -r neo4j`
- `useradd -r -g neo4j -d /opt/neo4j -s /bin/bash neo4j`

Ansible's `ansible.builtin.group` and `ansible.builtin.user` modules will be used for this.

### 1.7 Service Management

The script manages the Neo4j service using `systemctl`:

- `systemctl daemon-reload`
- `systemctl enable neo4j`
- `systemctl start neo4j`
- `systemctl status neo4j` (in monitoring script)
- `systemctl stop neo4j` (in display info)

Ansible's `ansible.builtin.systemd` module will be used for these actions.

### 1.8 Firewall Rules and Commands

The script configures `ufw` or `firewalld`:

- **UFW:**
  - `ufw --force enable`
  - `ufw allow ssh`
  - `ufw allow <port_range>/tcp` (for various Neo4j ports)
- **Firewalld:**
  - `systemctl enable firewalld`
  - `systemctl start firewalld`
  - `firewall-cmd --permanent --add-port=<port>/tcp`
  - `firewall-cmd --reload`

Ansible's `community.general.ufw` and `ansible.posix.firewalld` modules will be used.

### 1.9 Neo4j Configuration File Generation Logic

The `generate_core_config` and `generate_replica_config` functions dynamically create the `neo4j.conf` file using `cat << EOF`. This involves:

- Setting `dbms.mode` to `CORE` or `READ_REPLICA`.
- Calculating port numbers based on `server_id` and base ports.
- Using `get_server_ip` to determine `advertised_address`.
- Generating `causal_clustering.initial_discovery_members` based on the total number of core servers.
- Setting various memory, security, logging, and JVM parameters.

This will be handled by creating Jinja2 templates for `neo4j.conf` and passing appropriate variables and logic from Ansible.

### 1.10 Monitoring Script Creation and Crontab Entry

The `create_monitoring_script` function creates a shell script (`cluster_monitor.sh`) and adds it to the `neo4j` user's crontab.

- The script checks Neo4j status and restarts it if not running.
- It performs a health check via HTTP API.
- Crontab entry: `*/5 * * * * $NEO4J_HOME/cluster_monitor.sh`

Ansible's `ansible.builtin.template` module will be used for the script, and `ansible.builtin.cron` for the crontab entry.

This completes the initial analysis of the shell script. The next step is to design the overall Ansible playbook structure and define variables.



## Phase 2: Design Ansible Playbook Structure and Variables

This phase focuses on outlining the overall structure of the Ansible playbook and defining the variables that will be used throughout the automation process. The goal is to create a flexible and maintainable playbook that can be easily adapted to different deployment scenarios.

### 2.1 Overall Playbook Structure

The Ansible playbook will be organized into a main playbook file (e.g., `neo4j_cluster.yml`) and potentially separate roles for better organization and reusability. Given the sequential nature of the shell script, a single playbook with multiple tasks will be sufficient for this conversion, but roles could be introduced later for more complex environments.

The basic structure will include:

- **`hosts`**: This will define the target hosts where the Neo4j cluster components will be installed. We will use a dynamic inventory or define groups like `core_servers` and `read_replica_servers`.
- **`become`**: Set to `yes` to allow tasks to run with elevated privileges (sudo), as many of the installation steps require root access.
- **`vars`**: A section to define all the configurable parameters identified in Phase 1. This will allow users to easily modify installation paths, versions, and other settings without altering the task logic.
- **`tasks`**: The core of the playbook, containing a series of plays and tasks that execute the installation and configuration steps in a logical order.

```yaml
---
- name: Deploy Neo4j Cluster
  hosts: all_neo4j_servers
  become: yes
  vars:
    # Variables will be defined here
  tasks:
    # Tasks will be defined here
```

### 2.2 Ansible Variables Definition

Based on the analysis in Phase 1, the following variables will be defined in the `vars` section of the playbook. These variables correspond directly to the configuration variables found in the original shell script, ensuring that the Ansible playbook is as configurable as the original script.

```yaml
    neo4j_version: "5.15.0"
    neo4j_home: "/opt/neo4j"
    neo4j_user: "neo4j"
    neo4j_group: "neo4j"
    cluster_name: "neo4j-cluster"
    initial_password: "neo4j-admin"
    core_bolt_port_base: 7687
    read_replica_bolt_port_base: 8687
    http_port_base: 7474
    https_port_base: 7473
    backup_port_base: 6362
    cluster_port_base: 5000
    raft_port_base: 7000

    # Derived variables or variables for user input
    num_core_servers: 3 # Example default, will be prompted or passed via extra-vars
    num_read_replica_servers: 0 # Example default, will be prompted or passed via extra-vars
    server_type: "core" # 'core' or 'read_replica', will be prompted or passed via extra-vars
    server_id: 1 # ID for the current server, will be prompted or passed via extra-vars
```

### 2.3 Handling User Input and Inventory Structure

The original shell script prompts the user for the number of core and read replica servers, as well as the server type and ID for the current machine. In Ansible, this can be handled in several ways:

1.  **`vars_prompt`**: For interactive input during playbook execution. This is suitable if the playbook is run manually and interactive input is desired.
2.  **`extra-vars`**: Passing variables via the command line (`ansible-playbook -e 



## Phase 3: Implement Ansible Tasks for Java Installation

This phase focuses on creating the Ansible tasks required to install Java 17, which is a prerequisite for Neo4j 5.x. The tasks will be designed to be idempotent and will handle different Linux distributions (Debian/Ubuntu and RHEL/CentOS).

### 3.1 Task Implementation for Java Installation

The following Ansible tasks will be added to the main playbook to handle the installation of Java 17. These tasks will use the `ansible.builtin.package` module, which is a generic module that can use the appropriate package manager for the target system.

```yaml
    - name: Update package cache (Debian/Ubuntu)
      ansible.builtin.apt:
        update_cache: yes
      when: ansible_pkg_mgr == 'apt'

    - name: Install Java 17 (Debian/Ubuntu)
      ansible.builtin.apt:
        name: openjdk-17-jdk
        state: present
      when: ansible_pkg_mgr == 'apt'

    - name: Install Java 17 (RHEL/CentOS)
      ansible.builtin.yum:
        name: java-17-openjdk-devel
        state: present
      when: ansible_pkg_mgr == 'yum'
```

These tasks ensure that the package cache is updated on Debian-based systems before attempting to install the `openjdk-17-jdk` package. For Red Hat-based systems, the `java-17-openjdk-devel` package is installed using `yum`. The `when` condition ensures that the correct task is executed based on the detected package manager (`ansible_pkg_mgr`).




## Phase 4: Implement Ansible Tasks for Neo4j User/Group Creation and Installation

This phase covers the Ansible tasks required to create the dedicated Neo4j user and group, download the Neo4j enterprise package, extract it, move it to the designated installation directory, set appropriate ownership and permissions, and create symbolic links for easier execution.

### 4.1 Task Implementation for User and Group Creation

Ansible provides the `ansible.builtin.group` and `ansible.builtin.user` modules to manage system groups and users. These modules are idempotent, ensuring that the group and user are created only if they don't already exist.

```yaml
    - name: Create Neo4j group
      ansible.builtin.group:
        name: "{{ neo4j_group }}"
        state: present
        system: yes # Create as a system group

    - name: Create Neo4j user
      ansible.builtin.user:
        name: "{{ neo4j_user }}"
        group: "{{ neo4j_group }}"
        home: "{{ neo4j_home }}"
        shell: /bin/bash
        state: present
        system: yes # Create as a system user
```

### 4.2 Task Implementation for Neo4j Download and Installation

Downloading and installing Neo4j involves several steps: fetching the archive, uncompressing it, moving it to the final destination, and setting permissions. The `ansible.builtin.get_url` module will download the package, `ansible.builtin.unarchive` will extract it, and `ansible.builtin.file` will manage directories, ownership, and symbolic links.

```yaml
    - name: Ensure Neo4j home directory exists
      ansible.builtin.file:
        path: "{{ neo4j_home }}"
        state: directory
        owner: "{{ neo4j_user }}"
        group: "{{ neo4j_group }}"
        mode: "0755"

    - name: Download Neo4j Enterprise package
      ansible.builtin.get_url:
        url: "https://neo4j.com/artifact.php?name=neo4j-enterprise-{{ neo4j_version }}-unix.tar.gz"
        dest: "/tmp/neo4j-enterprise-{{ neo4j_version }}-unix.tar.gz"
        mode: "0644"
        owner: "{{ neo4j_user }}"
        group: "{{ neo4j_group }}"

    - name: Unarchive Neo4j package
      ansible.builtin.unarchive:
        src: "/tmp/neo4j-enterprise-{{ neo4j_version }}-unix.tar.gz"
        dest: "/opt/"
        remote_src: yes
        owner: "{{ neo4j_user }}"
        group: "{{ neo4j_group }}"

    - name: Move unarchived Neo4j directory to current link target
      ansible.builtin.command:
        cmd: "mv /opt/neo4j-enterprise-{{ neo4j_version }} {{ neo4j_home }}/current"
      args:
        creates: "{{ neo4j_home }}/current/bin/neo4j"

    - name: Set ownership and permissions for Neo4j home
      ansible.builtin.file:
        path: "{{ neo4j_home }}"
        owner: "{{ neo4j_user }}"
        group: "{{ neo4j_group }}"
        mode: "0755"
        recurse: yes

    - name: Create symlink for neo4j executable
      ansible.builtin.file:
        src: "{{ neo4j_home }}/current/bin/neo4j"
        dest: "/usr/local/bin/neo4j"
        state: link
        force: yes

    - name: Create symlink for neo4j-admin executable
      ansible.builtin.file:
        src: "{{ neo4j_home }}/current/bin/neo4j-admin"
        dest: "/usr/local/bin/neo4j-admin"
        state: link
        force: yes
```

**Note on `mv` command:** The `ansible.builtin.command` module is used for the `mv` operation because `ansible.builtin.file` does not directly support moving directories with renaming. The `creates` argument ensures idempotency by checking if the target file already exists before executing the command. This prevents errors if the playbook is run multiple times. Alternatively, a combination of `ansible.builtin.copy` and `ansible.builtin.file` with `state: absent` could be used, but `mv` is more direct for this specific scenario. The `remote_src: yes` in `unarchive` is crucial as the source file is on the remote machine (downloaded to `/tmp`).



## Phase 5: Implement Ansible Tasks for Firewall Configuration

This phase outlines the Ansible tasks for configuring the firewall on the target servers. The original shell script supports both `ufw` (Uncomplicated Firewall) for Debian/Ubuntu systems and `firewalld` for RHEL/CentOS systems. The Ansible playbook will use conditional logic to apply the correct firewall configuration based on the detected operating system.

### 5.1 Task Implementation for Firewall Configuration

Ansible provides dedicated modules for managing `ufw` and `firewalld`, making it straightforward to translate the shell script's logic. The tasks will ensure the firewall service is enabled and running, and then open the necessary ports for Neo4j communication.

#### 5.1.1 UFW Configuration (Debian/Ubuntu)

For Debian/Ubuntu systems, the `community.general.ufw` module will be used. This module allows for easy management of UFW rules, including enabling the firewall and allowing specific ports or services.

```yaml
    - name: Enable UFW (Debian/Ubuntu)
      community.general.ufw:
        state: enabled
        default_deny: incoming
        default_allow: outgoing
      when: ansible_pkg_mgr == 'apt'

    - name: Allow SSH through UFW (Debian/Ubuntu)
      community.general.ufw:
        rule: allow
        name: ssh
      when: ansible_pkg_mgr == 'apt'

    - name: Allow Neo4j Bolt ports through UFW (Debian/Ubuntu)
      community.general.ufw:
        rule: allow
        port: "{{ item }}"
        proto: tcp
      loop:
        - "{{ core_bolt_port_base }}"
        - "{{ read_replica_bolt_port_base }}"
      when: ansible_pkg_mgr == 'apt'

    - name: Allow Neo4j HTTP ports through UFW (Debian/Ubuntu)
      community.general.ufw:
        rule: allow
        port: "{{ item }}"
        proto: tcp
      loop:
        - "{{ http_port_base }}"
        - "{{ http_port_base + 10 }}" # For read replicas
      when: ansible_pkg_mgr == 'apt'

    - name: Allow Neo4j HTTPS ports through UFW (Debian/Ubuntu)
      community.general.ufw:
        rule: allow
        port: "{{ item }}"
        proto: tcp
      loop:
        - "{{ https_port_base }}"
        - "{{ https_port_base + 10 }}" # For read replicas
      when: ansible_pkg_mgr == 'apt'

    - name: Allow Neo4j Cluster communication ports through UFW (Debian/Ubuntu)
      community.general.ufw:
        rule: allow
        port: "{{ item }}"
        proto: tcp
      loop:
        - "{{ cluster_port_base }}"
        - "{{ cluster_port_base + 10 }}" # For read replicas
      when: ansible_pkg_mgr == 'apt'

    - name: Allow Neo4j Raft protocol ports through UFW (Debian/Ubuntu)
      community.general.ufw:
        rule: allow
        port: "{{ raft_port_base }}"
        proto: tcp
      when: ansible_pkg_mgr == 'apt'

    - name: Allow Neo4j Backup ports through UFW (Debian/Ubuntu)
      community.general.ufw:
        rule: allow
        port: "{{ backup_port_base }}"
        proto: tcp
      when: ansible_pkg_mgr == 'apt'
```

**Note:** The original script uses port ranges (e.g., `7687:7697/tcp`). For simplicity and clarity in Ansible, we will explicitly allow the base ports and the base ports + 10 (for read replicas) as the script implies these are the primary ports used. If a wider range is truly needed, a `with_sequence` loop could be used.

#### 5.1.2 Firewalld Configuration (RHEL/CentOS)

For RHEL/CentOS systems, the `ansible.posix.firewalld` module will be used. This module allows for adding permanent rules and reloading the firewall to apply changes.

```yaml
    - name: Enable and start Firewalld (RHEL/CentOS)
      ansible.builtin.systemd:
        name: firewalld
        state: started
        enabled: yes
      when: ansible_pkg_mgr == 'yum'

    - name: Allow Neo4j Bolt ports through Firewalld (RHEL/CentOS)
      ansible.posix.firewalld:
        port: "{{ item }}/tcp"
        permanent: yes
        state: enabled
      loop:
        - "{{ core_bolt_port_base }}"
        - "{{ read_replica_bolt_port_base }}"
      when: ansible_pkg_mgr == 'yum'

    - name: Allow Neo4j HTTP ports through Firewalld (RHEL/CentOS)
      ansible.posix.firewalld:
        port: "{{ item }}/tcp"
        permanent: yes
        state: enabled
      loop:
        - "{{ http_port_base }}"
        - "{{ http_port_base + 10 }}" # For read replicas
      when: ansible_pkg_mgr == 'yum'

    - name: Allow Neo4j HTTPS ports through Firewalld (RHEL/CentOS)
      ansible.posix.firewalld:
        port: "{{ item }}/tcp"
        permanent: yes
        state: enabled
      loop:
        - "{{ https_port_base }}"
        - "{{ https_port_base + 10 }}" # For read replicas
      when: ansible_pkg_mgr == 'yum'

    - name: Allow Neo4j Cluster communication ports through Firewalld (RHEL/CentOS)
      ansible.posix.firewalld:
        port: "{{ item }}/tcp"
        permanent: yes
        state: enabled
      loop:
        - "{{ cluster_port_base }}"
        - "{{ cluster_port_base + 10 }}" # For read replicas
      when: ansible_pkg_mgr == 'yum'

    - name: Allow Neo4j Raft protocol ports through Firewalld (RHEL/CentOS)
      ansible.posix.firewalld:
        port: "{{ raft_port_base }}/tcp"
        permanent: yes
        state: enabled
      when: ansible_pkg_mgr == 'yum'

    - name: Allow Neo4j Backup ports through Firewalld (RHEL/CentOS)
      ansible.posix.firewalld:
        port: "{{ backup_port_base }}/tcp"
        permanent: yes
        state: enabled
      when: ansible_pkg_mgr == 'yum'

    - name: Reload Firewalld (RHEL/CentOS)
      ansible.builtin.command:
        cmd: firewall-cmd --reload
      when: ansible_pkg_mgr == 'yum'
```

These tasks ensure that `firewalld` is running and the necessary ports are opened permanently. A final `firewall-cmd --reload` is executed to apply the changes. The `when` condition ensures that these tasks are only executed on systems using `firewalld`.



## Phase 6: Implement Ansible Tasks for Neo4j Configuration File Generation (Templates)

This phase focuses on translating the dynamic `neo4j.conf` generation logic from the shell script into Jinja2 templates for Ansible. The original script uses `cat << EOF` to create configuration files, which is effectively a form of templating. Ansible's `ansible.builtin.template` module is ideal for this, allowing us to use variables and conditional logic within the configuration files themselves.

### 6.1 Jinja2 Templates for `neo4j.conf`

Two main templates will be created: one for core servers and one for read replica servers, reflecting the `generate_core_config` and `generate_replica_config` functions in the shell script. These templates will be placed in a `templates` directory relative to the playbook.

#### 6.1.1 `neo4j.conf.j2` (Core Server Template)

This template will generate the `neo4j.conf` file for core servers. It will dynamically calculate port numbers and the `initial_discovery_members` list based on Ansible variables.

```jinja2
# Neo4j Core Server {{ server_id }} Configuration
# Generated by Ansible on {{ ansible_date_time.iso8601_basic }}

# Database mode
dbms.mode=CORE

# Server identification
dbms.default_database=neo4j
dbms.memory.heap.initial_size=2G
dbms.memory.heap.max_size=4G
dbms.memory.pagecache.size=2G

# Network connector configuration
dbms.connectors.default_listen_address=0.0.0.0
dbms.connectors.default_advertised_address={{ ansible_default_ipv4.address }}

# Bolt connector
dbms.connector.bolt.enabled=true
dbms.connector.bolt.listen_address=0.0.0.0:{{ core_bolt_port_base + server_id - 1 }}
dbms.connector.bolt.advertised_address={{ ansible_default_ipv4.address }}:{{ core_bolt_port_base + server_id - 1 }}

# HTTP connector
dbms.connector.http.enabled=true
dbms.connector.http.listen_address=0.0.0.0:{{ http_port_base + server_id - 1 }}
dbms.connector.http.advertised_address={{ ansible_default_ipv4.address }}:{{ http_port_base + server_id - 1 }}

# HTTPS connector
dbms.connector.https.enabled=true
dbms.connector.https.listen_address=0.0.0.0:{{ https_port_base + server_id - 1 }}
dbms.connector.https.advertised_address={{ ansible_default_ipv4.address }}:{{ https_port_base + server_id - 1 }}

# Cluster configuration
causal_clustering.expected_core_cluster_size={{ num_core_servers }}
causal_clustering.initial_discovery_members={%- for i in range(1, num_core_servers + 1) -%}
  {%- set current_cluster_port = cluster_port_base + i - 1 -%}
  {%- if i == 1 -%}
    server{{ i }}:{{ current_cluster_port }}
  {%- else -%}
    ,server{{ i }}:{{ current_cluster_port }}
  {%- endif -%}
{%- endfor %}
causal_clustering.discovery_listen_address=0.0.0.0:{{ cluster_port_base + server_id - 1 }}
causal_clustering.discovery_advertised_address={{ ansible_default_ipv4.address }}:{{ cluster_port_base + server_id - 1 }}
causal_clustering.transaction_listen_address=0.0.0.0:{{ raft_port_base + server_id - 1 }}
causal_clustering.transaction_advertised_address={{ ansible_default_ipv4.address }}:{{ raft_port_base + server_id - 1 }}
causal_clustering.raft_listen_address=0.0.0.0:{{ raft_port_base + server_id - 1 }}
causal_clustering.raft_advertised_address={{ ansible_default_ipv4.address }}:{{ raft_port_base + server_id - 1 }}

# Security
dbms.security.auth_enabled=true
dbms.security.procedures.unrestricted=jwt.*,apoc.*

# Logging
dbms.logs.query.enabled=true
dbms.logs.query.threshold=1s

# Performance tuning
dbms.tx_log.rotation.retention_policy=100M size
dbms.checkpoint.interval.time=30s

# JVM tuning
dbms.jvm.additional=-XX:+UseG1GC
dbms.jvm.additional=-XX:+UnlockExperimentalVMOptions
dbms.jvm.additional=-XX:+UseCGroupMemoryLimitForHeap

# Allow upgrade
dbms.allow_upgrade=true

# Enable metrics
metrics.enabled=true
metrics.csv.enabled=true
metrics.csv.interval=30s
```

**Explanation of Jinja2 Logic:**

- `{{ ansible_date_time.iso8601_basic }}`: Uses an Ansible fact to get the current date and time for the comment.
- `{{ ansible_default_ipv4.address }}`: Replaces the `get_server_ip` shell function by using an Ansible fact to get the primary IPv4 address of the server.
- Port calculations: `{{ core_bolt_port_base + server_id - 1 }}` directly translates the shell arithmetic into Jinja2 expressions.
- `initial_discovery_members`: This uses a `for` loop to iterate from 1 to `num_core_servers`. Inside the loop, it constructs the `serverX:portY` string and handles the comma separation for all but the first entry. This directly mimics the `generate_discovery_members` shell function.

#### 6.1.2 `neo4j_read_replica.conf.j2` (Read Replica Server Template)

This template will generate the `neo4j.conf` file for read replica servers. It has slightly different memory settings and port calculations compared to the core server.

```jinja2
# Neo4j Read Replica Server {{ server_id }} Configuration
# Generated by Ansible on {{ ansible_date_time.iso8601_basic }}

# Database mode
dbms.mode=READ_REPLICA

# Server identification
dbms.default_database=neo4j
dbms.memory.heap.initial_size=1G
dbms.memory.heap.max_size=2G
dbms.memory.pagecache.size=1G

# Network connector configuration
dbms.connectors.default_listen_address=0.0.0.0
dbms.connectors.default_advertised_address={{ ansible_default_ipv4.address }}

# Bolt connector
dbms.connector.bolt.enabled=true
dbms.connector.bolt.listen_address=0.0.0.0:{{ read_replica_bolt_port_base + server_id - 1 }}
dbms.connector.bolt.advertised_address={{ ansible_default_ipv4.address }}:{{ read_replica_bolt_port_base + server_id - 1 }}

# HTTP connector
dbms.connector.http.enabled=true
dbms.connector.http.listen_address=0.0.0.0:{{ http_port_base + 10 + server_id - 1 }}
dbms.connector.http.advertised_address={{ ansible_default_ipv4.address }}:{{ http_port_base + 10 + server_id - 1 }}

# HTTPS connector
dbms.connector.https.enabled=true
dbms.connector.https.listen_address=0.0.0.0:{{ https_port_base + 10 + server_id - 1 }}
dbms.connector.https.advertised_address={{ ansible_default_ipv4.address }}:{{ https_port_base + 10 + server_id - 1 }}

# Cluster configuration
causal_clustering.initial_discovery_members={%- for i in range(1, num_core_servers + 1) -%}
  {%- set current_cluster_port = cluster_port_base + i - 1 -%}
  {%- if i == 1 -%}
    server{{ i }}:{{ current_cluster_port }}
  {%- else -%}
    ,server{{ i }}:{{ current_cluster_port }}
  {%- endif -%}
{%- endfor %}
causal_clustering.discovery_listen_address=0.0.0.0:{{ cluster_port_base + 10 + server_id - 1 }}
causal_clustering.discovery_advertised_address={{ ansible_default_ipv4.address }}:{{ cluster_port_base + 10 + server_id - 1 }}

# Security
dbms.security.auth_enabled=true
dbms.security.procedures.unrestricted=jwt.*,apoc.*

# Logging
dbms.logs.query.enabled=true
dbms.logs.query.threshold=1s

# Performance tuning
dbms.tx_log.rotation.retention_policy=50M size

# JVM tuning
dbms.jvm.additional=-XX:+UseG1GC
dbms.jvm.additional=-XX:+UnlockExperimentalVMOptions
dbms.jvm.additional=-XX:+UseCGroupMemoryLimitForHeap

# Allow upgrade
dbms.allow_upgrade=true

# Enable metrics
metrics.enabled=true
metrics.csv.enabled=true
metrics.csv.interval=30s
```

### 6.2 Ansible Tasks to Deploy Configuration Files

The `ansible.builtin.template` module will be used to render these Jinja2 templates and deploy them to the correct location (`{{ neo4j_home }}/current/conf/neo4j.conf`) on the target servers. Conditional logic (`when`) will be used to apply the correct template based on the `server_type` variable.

```yaml
    - name: Deploy Neo4j core server configuration
      ansible.builtin.template:
        src: neo4j.conf.j2
        dest: "{{ neo4j_home }}/current/conf/neo4j.conf"
        owner: "{{ neo4j_user }}"
        group: "{{ neo4j_group }}"
        mode: "0644"
      when: server_type == 'core'

    - name: Deploy Neo4j read replica server configuration
      ansible.builtin.template:
        src: neo4j_read_replica.conf.j2
        dest: "{{ neo4j_home }}/current/conf/neo4j.conf"
        owner: "{{ neo4j_user }}"
        group: "{{ neo4j_group }}"
        mode: "0644"
      when: server_type == 'read_replica'
```

These tasks ensure that the correct `neo4j.conf` file is generated and placed on each server, with the appropriate ownership and permissions. The `server_type` variable, which would be passed as an `extra-var` or prompted from the user, determines which template is used.



## Phase 7: Implement Ansible Tasks for Systemd Service and Initial Password

This phase covers the creation and management of the Neo4j systemd service and the setting of the initial administrator password. The original shell script creates a `neo4j.service` file, enables and starts the service, and then sets the initial password after a brief delay to allow the service to start.

### 7.1 Jinja2 Template for `neo4j.service`

The `neo4j.service` file will be created using a Jinja2 template to allow for dynamic paths and user/group information. This template will be placed in the `templates` directory.

```jinja2
[Unit]
Description=Neo4j Graph Database
After=network.target
Wants=network.target

[Service]
ExecStart={{ neo4j_home }}/current/bin/neo4j console
Restart=on-failure
User={{ neo4j_user }}
Group={{ neo4j_group }}
Environment=NEO4J_HOME={{ neo4j_home }}/current
Environment=NEO4J_CONF={{ neo4j_home }}/current/conf
LimitNOFILE=60000
TimeoutSec=120

[Install]
WantedBy=multi-user.target
```

**Explanation of Jinja2 Logic:**

- `{{ neo4j_home }}`, `{{ neo4j_user }}`, `{{ neo4j_group }}`: These variables are directly substituted from the Ansible playbook's `vars` section, ensuring consistency and configurability of the service file.

### 7.2 Ansible Tasks for Systemd Service Management

The `ansible.builtin.systemd` module is used to manage systemd services. It can deploy the service file, reload the daemon, enable, and start the service.

```yaml
    - name: Deploy Neo4j systemd service file
      ansible.builtin.template:
        src: neo4j.service.j2
        dest: /etc/systemd/system/neo4j.service
        owner: root
        group: root
        mode: "0644"

    - name: Reload systemd daemon
      ansible.builtin.systemd:
        daemon_reload: yes

    - name: Enable Neo4j service
      ansible.builtin.systemd:
        name: neo4j
        enabled: yes

    - name: Start Neo4j service
      ansible.builtin.systemd:
        name: neo4j
        state: started
```

### 7.3 Ansible Task for Setting Initial Password

Setting the initial password requires the Neo4j service to be running. The original script uses a `sleep 10` command. In Ansible, a `pause` task can be used, followed by the command to set the password. The `ansible.builtin.command` module will be used, and the `creates` argument will ensure idempotency by preventing the command from running if the password has already been set (though this is a heuristic and might need refinement for robust production environments).

```yaml
    - name: Pause for Neo4j service to start
      ansible.builtin.pause:
        seconds: 10
      when: server_type == 'core' # Only set password on core servers

    - name: Set initial Neo4j password
      ansible.builtin.command:
        cmd: "{{ neo4j_home }}/current/bin/neo4j-admin dbms set-initial-password {{ initial_password }}"
      become_user: "{{ neo4j_user }}"
      args:
        creates: "{{ neo4j_home }}/current/data/databases/neo4j/neostore.transaction.db.0"
      when: server_type == 'core' # Only set password on core servers
```

**Note on Idempotency for Password Setting:** The `creates` argument for the `set-initial-password` command is a best-effort attempt at idempotency. It assumes that the presence of the `neostore.transaction.db.0` file indicates that the database has been initialized and the password has been set. In a real-world scenario, a more robust check might involve querying the Neo4j API to verify the password status or using a custom fact. Additionally, the `when: server_type == 'core'` condition ensures that this task only runs on core servers, as read replicas do not manage the initial password in the same way. The `become_user` directive ensures the command is run as the `neo4j` user, mimicking the `sudo -u $NEO4J_USER` from the shell script.



## Phase 8: Implement Ansible Tasks for Monitoring Script

This phase focuses on converting the shell script's monitoring functionality into Ansible tasks. The original script creates a `cluster_monitor.sh` file and adds a cron job to execute it periodically. Ansible provides modules to handle both file creation (via templates) and cron job management.

### 8.1 Jinja2 Template for `cluster_monitor.sh`

The `cluster_monitor.sh` script will be created using a Jinja2 template. This allows for dynamic insertion of paths and other variables into the script. The template will be placed in the `templates` directory.

```jinja2
#!/bin/bash

# Neo4j Cluster Monitoring Script
NEO4J_HOME="{{ neo4j_home }}/current"
LOG_FILE="/var/log/neo4j/cluster_monitor.log"

check_cluster_status() {
    echo "$(date): Checking cluster status..." >> $LOG_FILE
    
    # Check if Neo4j is running
    if ! pgrep -f "neo4j" > /dev/null; then
        echo "$(date): ERROR - Neo4j is not running!" >> $LOG_FILE
        sudo systemctl start neo4j
        return 1
    fi
    
    # Check cluster health via HTTP API
    local http_port=$(grep "dbms.connector.http.listen_address" $NEO4J_HOME/conf/neo4j.conf | cut -d':' -f2)
    local health_check=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${http_port}/db/manage/server/core/available" || echo "000")
    
    if [[ "$health_check" == "200" ]]; then
        echo "$(date): Cluster status OK" >> $LOG_FILE
        return 0
    else
        echo "$(date): WARNING - Cluster health check failed (HTTP $health_check)" >> $LOG_FILE
        return 1
    fi
}

# Run the check
check_cluster_status
```

**Explanation of Jinja2 Logic:**

- `{{ neo4j_home }}`: This variable is used to dynamically set the `NEO4J_HOME` path within the monitoring script, ensuring it points to the correct Neo4j installation directory.

### 8.2 Ansible Tasks for Deploying Monitoring Script and Crontab Entry

Ansible's `ansible.builtin.template` module will be used to deploy the monitoring script, and the `ansible.builtin.cron` module will manage the crontab entry.

```yaml
    - name: Deploy cluster monitoring script
      ansible.builtin.template:
        src: cluster_monitor.sh.j2
        dest: "{{ neo4j_home }}/cluster_monitor.sh"
        owner: "{{ neo4j_user }}"
        group: "{{ neo4j_group }}"
        mode: "0755"

    - name: Add cluster monitoring to crontab
      ansible.builtin.cron:
        name: "Neo4j Cluster Monitor"
        minute: "*/5"
        user: "{{ neo4j_user }}"
        job: "{{ neo4j_home }}/cluster_monitor.sh"
```

These tasks ensure that the monitoring script is placed in the correct location with executable permissions and owned by the `neo4j` user. The `ansible.builtin.cron` module then adds a cron job that runs the script every 5 minutes under the `neo4j` user, replicating the functionality of the original shell script's crontab entry.



## Phase 9: Review and Refine Ansible Playbook

This phase involves a comprehensive review of the generated Ansible playbook to ensure it adheres to best practices, is idempotent, well-documented, and ready for deployment. While a full testing environment is beyond the scope of this document, key considerations for review are outlined.

### 9.1 Idempotency and Best Practices

Ansible tasks are designed to be idempotent, meaning they can be run multiple times without causing unintended side effects. Throughout the playbook, modules like `ansible.builtin.apt`, `ansible.builtin.yum`, `ansible.builtin.group`, `ansible.builtin.user`, `ansible.builtin.file`, `ansible.builtin.unarchive`, `ansible.builtin.template`, `ansible.builtin.systemd`, and `ansible.builtin.cron` inherently support idempotency. For tasks that involve running commands (`ansible.builtin.command`), the `creates` argument has been used where appropriate to ensure the command only runs if the specified file does not exist.

**Key Best Practices Applied:**

- **Modularity:** The playbook is structured with clear tasks, and templates are used for configuration files, promoting reusability and readability.
- **Variables:** All configurable parameters are defined as variables at the top of the playbook, making it easy to customize deployments without modifying task logic.
- **Conditional Execution:** `when` clauses are used extensively to ensure tasks are executed only on relevant operating systems or server types.
- **Privilege Escalation:** `become: yes` is used at the playbook level, and `become_user` is used for specific tasks (like setting the initial password) to run commands as the `neo4j` user, mimicking the original script's behavior.
- **Error Handling:** While not explicitly added as `block/rescue` in this conversion, Ansible's default behavior is to stop on errors, which is generally desired for installation playbooks. More advanced error handling could be added if specific recovery mechanisms are needed.

### 9.2 Comments and Documentation

The Ansible playbook and templates are commented to explain the purpose of each section and complex logic. Further documentation would typically include:

- **`README.md`:** A comprehensive `README.md` file in the `neo4j_ansible` directory explaining how to use the playbook, prerequisites, variable explanations, and example inventory files.
- **Inventory Examples:** Providing example `hosts` files for different cluster configurations.
- **Usage Instructions:** Clear instructions on how to run the playbook, including passing `extra-vars` or using `vars_prompt`.

### 9.3 Testing Considerations

While this document provides the conversion, actual deployment would require thorough testing. Considerations for testing include:

- **Local Testing:** Using Vagrant or Docker to spin up virtual machines and test the playbook in isolated environments.
- **Idempotency Testing:** Running the playbook multiple times to ensure it produces the same result and does not break on subsequent runs.
- **Role-Based Testing:** If the playbook were broken into roles, each role could be tested independently.
- **Integration Testing:** Deploying a full cluster and verifying functionality, including inter-node communication, data replication, and monitoring.

This concludes the review and refinement phase. The next step is to deliver the generated Ansible playbook and associated files to the user.

