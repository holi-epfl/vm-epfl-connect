cd /home/holi/.wsl-connect/connect.sh
killall ngrok
ngrok tcp 22 --log=stdout | grep "url=" > connected_info.log &
sleep 2
curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url' > ngrok_info.log

