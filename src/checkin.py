import os
from playwright.sync_api import sync_playwright


def checkin():
    cookie_str = os.environ.get('ZAIMANHUA_COOKIE')
    if not cookie_str:
        print("Error: ZAIMANHUA_COOKIE not set")
        return False

    # 解析 Cookie 字符串为 Playwright 格式
    cookies = []
    for item in cookie_str.split(';'):
        item = item.strip()
        if '=' in item:
            name, value = item.split('=', 1)
            cookies.append({
                'name': name.strip(),
                'value': value.strip(),
                'domain': '.zaimanhua.com',
                'path': '/'
            })

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()

        # 添加 Cookie
        context.add_cookies(cookies)

        page = context.new_page()
        page.goto('https://i.zaimanhua.com/')

        # 等待页面加载
        page.wait_for_load_state('networkidle')

        try:
            # 等待签到按钮出现
            page.wait_for_selector('.ant-btn-primary', timeout=10000)

            # 点击签到按钮
            page.click('.ant-btn-primary')

            # 等待操作完成
            page.wait_for_timeout(2000)

            print("签到成功！")
            result = True
        except Exception as e:
            print(f"签到失败: {e}")
            result = False
        finally:
            browser.close()

        return result


if __name__ == '__main__':
    success = checkin()
    exit(0 if success else 1)
