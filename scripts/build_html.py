#!/usr/bin/env python3
"""CSS/JS를 index.html에 인라인으로 합쳐 단일 실행 파일 생성"""

with open('omok/style.css', encoding='utf-8') as f:
    css = f.read()

with open('omok/game.js', encoding='utf-8') as f:
    js = f.read()

with open('omok/index.html', encoding='utf-8') as f:
    html = f.read()

html = html.replace(
    '<link rel="stylesheet" href="style.css">',
    f'<style>\n{css}\n</style>'
)
html = html.replace(
    '<script src="game.js"></script>',
    f'<script>\n{js}\n</script>'
)

with open('omok-game.html', 'w', encoding='utf-8') as f:
    f.write(html)

print('✅ omok-game.html 생성 완료!')
