resource "aws_instance" "dc1" {
  ami           = var.ami                #"ami-0c55b159cbfafe1f0" # Latest Windows Server 2019 AMI
  instance_type = var.instance_type      # "t2.medium"
  subnet_id     = var.private_subnet_dc1 # aws_subnet.private_subnet.id
  key_name      = var.key_name           # "your-key-pair" # Replace with your key pair

  vpc_security_group_ids = var.security_group
  network_interface {
    network_interface_id = aws_network_interface.dc01.id
    device_index         = 0
  }

  # Install AD DS and DNS via User Data
  user_data = <<EOF
<powershell>
# Step 1: Change Computer Name
$NewComputerName = "${var.computer_name_dc1}"      # The new computer name
$DomainName = "${var.domain_name}"             # The domain name to create or join
$SafeModePassword = ConvertTo-SecureString "${var.safemode_password}" -AsPlainText -Force

# Get current computer name
$CurrentComputerName = (Get-WmiObject Win32_ComputerSystem).Name

# Change computer name if different
if ($CurrentComputerName -ne $NewComputerName) {
    Rename-Computer -NewName $NewComputerName -Force
    Restart-Computer -Force
}

# Wait for restart to complete before continuing (60 seconds delay)
Start-Sleep -Seconds 60

# Step 2: Install Active Directory and DNS roles
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Install-WindowsFeature -Name DNS -IncludeManagementTools

# Step 3: Promote the server to a Domain Controller
if (-Not (Get-ADDomain -ErrorAction SilentlyContinue)) {
    Install-ADDSForest `
        -DomainName $DomainName `
        -SafeModeAdministratorPassword $SafeModePassword `
        -InstallDNS `
        -Force
} else {
    Write-Host "Domain already exists, skipping promotion."
}

</powershell>
EOF

  tags = {
    Name = "DC1"
  }
}

resource "aws_network_interface" "dc01" {
  subnet_id       = var.private_subnet_dc1
  private_ips     = ["10.50.3.10"]
  security_groups = var.security_group
  tags = {
    Name = "DC01 nw"
  }
}

resource "aws_instance" "dc2" {
  ami           = var.ami                #"ami-0c55b159cbfafe1f0" # Latest Windows Server 2019 AMI
  instance_type = var.instance_type      #"t2.medium"
  subnet_id     = var.private_subnet_dc2 #aws_subnet.private_subnet.id
  key_name      = var.key_name           #"your-key-pair" # Replace with your key pair

  vpc_security_group_ids = var.security_group # [aws_security_group.dc_sg.id]

  network_interface {
    network_interface_id = aws_network_interface.dc02.id
    device_index         = 0
  }
  # Install AD DS and DNS via User Data
  user_data = <<EOF
<powershell>
# Step 1: Change Computer Name
$NewComputerName = "${var.computer_name_dc2}"      # The new computer name
$DomainName = "${var.domain_name}"             # The domain name to create or join
$SafeModePassword = ConvertTo-SecureString "${var.safemode_password}" -AsPlainText -Force

# Get current computer name
$CurrentComputerName = (Get-WmiObject Win32_ComputerSystem).Name

# Change computer name if different
if ($CurrentComputerName -ne $NewComputerName) {
    Rename-Computer -NewName $NewComputerName -Force
    Restart-Computer -Force
}

# Wait for restart to complete before continuing (60 seconds delay)
Start-Sleep -Seconds 60

# Step 2: Install Active Directory and DNS roles
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Install-WindowsFeature -Name DNS -IncludeManagementTools

# Step 3: Promote the server to a Domain Controller
if (-Not (Get-ADDomain -ErrorAction SilentlyContinue)) {
    Install-ADDSForest `
        -DomainName $DomainName `
        -SafeModeAdministratorPassword $SafeModePassword `
        -InstallDNS `
        -Force
} else {
    Write-Host "Domain already exists, skipping promotion."
}

</powershell>
EOF

  tags = {
    Name = "DC2"
  }
}

resource "aws_network_interface" "dc02" {
  subnet_id       = var.private_subnet_dc1
  private_ips     = ["10.50.4.10"]
  security_groups = var.security_group
  tags = {
    Name = "DC02 nw"
  }
}
