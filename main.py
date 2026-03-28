import flet as ft
import yt_dlp
import os
import threading

def main(page: ft.Page):
    # إعدادات الواجهة
    page.title = "R Cima Plus"
    page.theme_mode = ft.ThemeMode.DARK
    page.rtl = True  # تفعيل اللغة العربية تلقائياً
    page.padding = 20
    page.scroll = ft.ScrollMode.AUTO

    url_input = ft.TextField(label="ضع رابط الفيديو أو ابحث هنا...", expand=True, border_color=ft.colors.BLUE_400)
    results_col = ft.Column(spacing=20)

    # دالة إظهار الإشعارات السفلية
    def show_msg(msg, color):
        page.snack_bar = ft.SnackBar(ft.Text(msg, color=ft.colors.WHITE, weight=ft.FontWeight.BOLD), bgcolor=color)
        page.snack_bar.open = True
        page.update()

    # دالة البحث
    def do_search(query):
        try:
            is_url = query.startswith("http")
            sq = query if is_url else f"ytsearch5:{query}"
            ydl_opts = {'quiet': True, 'extract_flat': True}
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(sq, download=False)
                entries = [info] if is_url else info.get('entries', [])

                for e in entries:
                    if not e: continue
                    title = e.get('title', 'فيديو بدون عنوان')
                    thumb = e.get('thumbnail', '')
                    url = e.get('url') or e.get('webpage_url')

                    # تصميم كارت الفيديو
                    card = ft.Card(
                        elevation=8,
                        content=ft.Container(
                            padding=15,
                            content=ft.Column([
                                ft.Image(src=thumb, height=180, fit=ft.ImageFit.COVER, border_radius=10),
                                ft.Text(title, weight=ft.FontWeight.BOLD, text_align=ft.TextAlign.CENTER, size=16),
                                ft.Row([
                                    ft.ElevatedButton("تحميل فيديو", icon=ft.icons.VIDEO_FILE, bgcolor=ft.colors.GREEN_700, color=ft.colors.WHITE, on_click=lambda _, u=url: start_dl(u, 'video')),
                                    ft.ElevatedButton("تحميل صوت", icon=ft.icons.AUDIO_FILE, bgcolor=ft.colors.ORANGE_700, color=ft.colors.WHITE, on_click=lambda _, u=url: start_dl(u, 'audio')),
                                ], alignment=ft.MainAxisAlignment.CENTER)
                            ])
                        )
                    )
                    results_col.controls.append(card)
            show_msg("تم جلب النتائج بنجاح! 🎉", ft.colors.GREEN_700)
        except Exception as ex:
            show_msg("حدث خطأ، تأكد من الرابط أو الإنترنت.", ft.colors.RED_700)
        page.update()

    def search_btn_click(e):
        if not url_input.value:
            show_msg("يرجى إدخال كلمة بحث أو رابط أولاً!", ft.colors.RED_700)
            return
        show_msg("جاري البحث... لحظات من فضلك 🔍", ft.colors.BLUE_700)
        results_col.controls.clear()
        page.update()
        threading.Thread(target=do_search, args=(url_input.value,)).start()

    # دالة التحميل
    def dl_logic(url, type):
        try:
            # مسار التنزيلات العام في الأندرويد
            path = "/storage/emulated/0/Download"
            if not os.path.exists(path):
                path = os.path.expanduser("~/Downloads")
            
            ydl_opts = {
                'outtmpl': f'{path}/%(title)s.%(ext)s',
                'quiet': True,
                'no_warnings': True,
                # جلب الصيغ المباشرة لتجنب مشاكل التحويل
                'format': 'bestaudio[ext=m4a]/bestaudio' if type == 'audio' else 'best[ext=mp4]/best'
            }
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([url])
            show_msg("تم التحميل بنجاح في مجلد Downloads! ✅", ft.colors.GREEN_700)
        except Exception as ex:
            show_msg("حدث خطأ أثناء التحميل ❌", ft.colors.RED_700)

    def start_dl(url, type):
        show_msg("بدأ التحميل في الخلفية... يرجى الانتظار ⏳", ft.colors.BLUE_700)
        threading.Thread(target=dl_logic, args=(url, type)).start()

    # ترتيب العناصر في الشاشة
    header = ft.Row([
        ft.Icon(ft.icons.PLAY_CIRCLE_FILL, color=ft.colors.BLUE_500, size=40),
        ft.Text("R Cima Plus", size=28, weight=ft.FontWeight.BOLD, color=ft.colors.BLUE_500)
    ], alignment=ft.MainAxisAlignment.CENTER)

    search_row = ft.Row([
        url_input,
        ft.FloatingActionButton(icon=ft.icons.SEARCH, on_click=search_btn_click, bgcolor=ft.colors.BLUE_600, foreground_color=ft.colors.WHITE)
    ])

    page.add(
        header,
        ft.Divider(height=10, color=ft.colors.TRANSPARENT),
        search_row,
        ft.Divider(height=20, color=ft.colors.WHITE24),
        results_col
    )

ft.app(target=main)
