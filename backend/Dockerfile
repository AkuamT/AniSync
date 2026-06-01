FROM python:3.11-slim

WORKDIR /app

# 先复制依赖清单，利用 Docker 缓存层
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制所有后端代码
COPY . .

# 暴露端口
EXPOSE 8080

# 启动服务
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
