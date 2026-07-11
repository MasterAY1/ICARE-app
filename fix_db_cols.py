import os

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("query.eq('Officer',", "query.eq('officer',")
content = content.replace("query.eq('Branch',", "query.eq('branch',")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("DB columns fixed.")
