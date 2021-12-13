#!/bin/bash
if [[ ! -f mushr_install.bash ]]; then
  echo Wrong directory! Change directory to the one containing mushr_install.bash
  exit 1
fi
PATH=pwd

# Get user info
read -p "Are you installing on robot and need all the sensor drivers? (y/n) " -r
echo
if [[ ! -f .install_run.txt ]]; then
  touch .install_run.txt # Prevents running these commands multiple times. Bit hacky
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo Running robot specific commands
    # Need to connect to ydlidar
    git clone https://github.com/prl-mushr/ydlidar
    cd ydlidar
    sudo sh startup/initenv.sh
    cd .. && rm -rf ydlidar

    # Setup VESC udev rules. Following commands adapted from:
    # https://github.com/RacecarJ/installRACECARUdev
    echo "ACTION==\"add\", ATTRS{idVendor}==\"0483\", ATTRS{idProduct}==\"5740\", SYMLINK+=\"vesc\"" > /tmp/10-vesc.rules
    sudo mv /tmp/10-vesc.rules /etc/udev/rules.d/
    sudo udevadm control --reload-rules && udevadm trigger

    # Install GPIO library
    pip install Jetson.GPIO
    sudo groupadd -f -r gpio
    sudo usermod -a -G gpio $USER
    wget https://raw.githubusercontent.com/NVIDIA/jetson-gpio/master/lib/python/Jetson/GPIO/99-gpio.rules -O /etc/udev/rules.d/99-gpio.rules
    sudo udevadm control --reload-rules && udevadm trigger

    # Setup rc.local
    echo '#!/bin/sh -e' > /tmp/rc.local
    echo "echo 200 > /sys/class/gpio/export" >> /tmp/rc.local
    echo "chmod go+w /sys/class/gpio/gpio200/direction" >> /tmp/rc.local
    echo "chmod go+rw /sys/class/gpio/gpio200/value" >> /tmp/rc.local
    echo "echo \"in\" > /sys/class/gpio/gpio200/direction" >> /tmp/rc.local
    echo "rs-enumerate-devices &> /dev/null" >> /tmp/rc.local
    echo "nvpmodel -m 0" >> /tmp/rc.local
    echo "sleep 60 && jetson_clocks" >> /tmp/rc.local
    sudo mv /tmp/rc.local /etc/rc.local
    export REAL_ROBOT=1
  else
    export REAL_ROBOT=0
  fi

  # Make catkin_ws outside container for easy editing
  mkdir -p ../../../catkin_ws/src
  cd ../../../ && mv mushr catkin_ws/src/mushr
  WS_PATH=pwd
  apt-get install -y python3-vcstool
  cd catkin_ws/src/ && vcs import < mushr/repos.yaml

fi

# Build container
cd $PATH
docker-compose up

read -p $'Add "xhost +" to .bashrc? This enables GUI from docker but is a security risk.\nIf no, each time you run the docker container you will need to execute this command.\nAdd xhost + .bashrc? (y/n) ' -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo WARNING: Adding "xhost" + to .bashrc 
  echo "xhost +" >> ~/.bashrc && source ~/.bashrc
fi