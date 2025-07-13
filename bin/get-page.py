import sys
from selenium import webdriver

args = sys.argv

url = args[1]

driver = webdriver.Chrome()

driver.get(url)

driver.implicitly_wait(30)  # wait 30 seconds

page_source = driver.page_source

driver.quit()

print(page_source.encode("utf-8"))
