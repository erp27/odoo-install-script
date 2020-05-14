# Odoo v.12 install script

Script for installing a clean Odoo v.12 in Linux

# Linux install

```
git clone https://github.com/erp27/odoo-install-script.git
cd ./odoo-install-script
./odoo_install.sh
```

## Default setup

Extra addons directory:

`/home/odoo12/custom/addons`

`/home/odoo12/.local/share/Odoo/addons/12.0`

Start Odoo service:

```bash
sudo systemctl start odoo12
```

Stop Odoo service:

```bash
sudo systemctl stop odoo12
```

Restart Odoo service:

```bash
sudo systemctl restart odoo12
```

Show log:

```bash
sudo tail -f /var/log/odoo12/odoo12.log
```

## Author

https://github.com/erp27

> Слава Україні та її Героям!
