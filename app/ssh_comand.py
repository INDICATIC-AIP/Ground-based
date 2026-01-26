import paramiko

def send_ssh_command(hostname, username, password, command, port=22):
    """
    Send a command via SSH and return the output
    
    Args:
        hostname (str): SSH server hostname or IP
        username (str): SSH username
        password (str): SSH password
        command (str): Command to execute
        port (int): SSH port (default: 22)
    
    Returns:
        tuple: (stdout, stderr, exit_status)
    """
    try:
        # Create SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        # Connect to server
        ssh.connect(hostname, port=port, username=username, password=password)
        
        # Execute command
        stdin, stdout, stderr = ssh.exec_command(command)
        
        # Get output
        output = stdout.read().decode('utf-8')
        error = stderr.read().decode('utf-8')
        exit_status = stdout.channel.recv_exit_status()
        
        # Close connection
        ssh.close()
        
        return output, error, exit_status
        
    except Exception as e:
        return None, str(e), -1

