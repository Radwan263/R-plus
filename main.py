import flet as ft
import os
import threading
import sys

# محاولة استيراد yt_dlp من الملف المحلي أو من المكتبة المثبتة
try:
    import yt_dlp_file as yt_dlp
except ImportError:
    try:
        import yt_dlp
    except ImportError:
        # في حالة الفشل التام (لن يحدث إذا تم تضمين الملف)
        yt_dlp = None

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
        if yt_dlp is None:
            show_msg("خطأ: مكتبة التحميل غير متوفرة!", ft.colors.RED_700)
            return
            
        try:
            is_url = query.startswith("http")
            sq = query if is_url else f"ytsearch5:{query}"
            ydl_opts = {'quiet': True, 'extract_flat': True, 'no_warnings': True}
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(sq, download=False)
                entries = [info] if is_url else info.get('entries', [])

                if not entries:
                    show_msg("لم يتم العثور على نتائج.", ft.colors.ORANGE_700)
                    return

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
            show_msg(f"حدث خطأ: {str(ex)[:50]}", ft.colors.RED_700)
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
            # محاولة تحديد مسار التحميل في أندرويد
            if os.name == 'posix' and hasattr(sys, 'getandroidapilevel'):
                # نحن على أندرويد
                path = "/storage/emulated/0/Download"
            else:
                path = os.path.join(os.path.expanduser("~"), "Downloads")
                
            if not os.path.exists(path):
                try:
                    os.makedirs(path, exist_ok=True)
                except:
                    path = "." # العودة للمجلد الحالي إذا فشل كل شيء
            
            ydl_opts = {
                'outtmpl': f'{path}/%(title)s.%(ext)s',
                'quiet': True,
                'no_warnings': True,
                'format': 'bestaudio[ext=m4a]/bestaudio' if type == 'audio' else 'best[ext=mp4]/best'
            }
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([url])
            show_msg(f"تم التحميل بنجاح في: {path} ✅", ft.colors.GREEN_700)
        except Exception as ex:
            show_msg(f"خطأ في التحميل: {str(ex)[:50]}", ft.colors.RED_700)

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
