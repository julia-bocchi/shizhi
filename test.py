import requests

url = "http://127.0.0.1:8000/api/v1/tts/briefing"

# 正常传JSON参数
resp1 = requests.post(url, json={"text": "hello"})
print("带text参数：", resp1.text)

# 空请求
resp2 = requests.post(url,json={})
print("无参数：", resp2.text)