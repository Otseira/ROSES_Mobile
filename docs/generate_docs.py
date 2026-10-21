#!/usr/bin/env python3
import os
import subprocess
import textwrap

class PSReport:
    def __init__(self, filename, title, subtitle, doc_type="PANDUAN RESMI"):
        self.filename = filename
        self.title = title
        self.subtitle = subtitle
        self.doc_type = doc_type
        self.pages = []
        self.current_page = []
        self.y = 750
        self.margin_left = 50
        self.margin_right = 545
        self.width = self.margin_right - self.margin_left
        self.page_num = 1
        
    def add_cover(self):
        # Cover page
        p = []
        # Background accent bars
        p.append("0.12 0.35 0.75 setrgbcolor")
        p.append("0 822 595 20 rectfill")
        p.append("0.08 0.65 0.55 setrgbcolor")
        p.append("0 816 595 6 rectfill")
        
        # Badge
        p.append("0.90 0.94 1.00 setrgbcolor")
        p.append("50 710 495 32 rectfill")
        p.append("0.15 0.45 0.85 setrgbcolor")
        p.append("50 710 495 32 rectstroke")
        p.append("/Helvetica-Bold findfont 11 scalefont setfont")
        p.append("0.12 0.35 0.75 setrgbcolor")
        badge_text = f"RSKB ROPANASURI  |  {self.doc_type.upper()}"
        p.append(f"70 722 moveto ({badge_text}) show")
        
        # Main Title (Wrap if needed)
        title_lines = textwrap.wrap(self.title, width=28)
        y_pos = 640
        p.append("/Helvetica-Bold findfont 24 scalefont setfont")
        p.append("0.08 0.12 0.22 setrgbcolor")
        for line in title_lines:
            p.append(f"50 {y_pos} moveto ({line}) show")
            y_pos -= 32
            
        # Subtitle
        y_pos -= 8
        p.append("0.15 0.45 0.85 setrgbcolor")
        p.append("/Helvetica findfont 13 scalefont setfont")
        sub_lines = textwrap.wrap(self.subtitle, width=50)
        for line in sub_lines:
            p.append(f"50 {y_pos} moveto ({line}) show")
            y_pos -= 20
            
        # Decorative divider
        y_pos -= 15
        p.append("0.85 0.88 0.92 setrgbcolor")
        p.append(f"50 {y_pos} moveto 545 {y_pos} lineto stroke")
        
        # Overview Description Box
        y_pos -= 35
        p.append("0.97 0.98 1.00 setrgbcolor")
        p.append(f"50 {y_pos - 100} 495 120 rectfill")
        p.append("0.80 0.86 0.95 setrgbcolor")
        p.append(f"50 {y_pos - 100} 495 120 rectstroke")
        p.append("0.15 0.45 0.85 setrgbcolor")
        p.append(f"50 {y_pos - 100} 5 120 rectfill") # left bar
        
        p.append("/Helvetica-Bold findfont 11 scalefont setfont")
        p.append("0.12 0.35 0.75 setrgbcolor")
        p.append(f"68 {y_pos} moveto (TENTANG MODUL PANDUAN INI) show")
        
        p.append("/Helvetica findfont 9.5 scalefont setfont")
        p.append("0.25 0.30 0.38 setrgbcolor")
        desc = (
            "Buku panduan ini disusun khusus dengan bahasa yang ringkas, jelas, dan mudah dipahami "
            "oleh seluruh staf medis, perawat, penunjang, hingga jajaran manajemen RSKB Ropanasuri. "
            "Setiap tahapan dilengkapi dengan instruksi bernomor urut, tips praktis, serta solusi cepat "
            "atas kendala yang sering terjadi di lapangan."
        )
        desc_lines = textwrap.wrap(desc, width=64)
        dy = y_pos - 20
        for dl in desc_lines:
            p.append(f"68 {dy} moveto ({dl}) show")
            dy -= 15
            
        # Target Audience Box
        y_pos -= 150
        p.append("0.96 0.97 0.98 setrgbcolor")
        p.append(f"50 {y_pos - 60} 495 80 rectfill")
        p.append("0.88 0.90 0.94 setrgbcolor")
        p.append(f"50 {y_pos - 60} 495 80 rectstroke")
        
        p.append("/Helvetica-Bold findfont 10.5 scalefont setfont")
        p.append("0.15 0.20 0.30 setrgbcolor")
        p.append(f"68 {y_pos} moveto (INFORMASI DOKUMEN & DISTRIBUSI) show")
        
        p.append("/Helvetica findfont 9 scalefont setfont")
        p.append("0.35 0.40 0.48 setrgbcolor")
        p.append(f"68 {y_pos - 18} moveto (Edisi / Versi       : Versi 2.0 - Pembaruan Oktober 2026) show")
        p.append(f"68 {y_pos - 32} moveto (Penyusun             : Tim SIMRS & Teknologi Informasi RSKB Ropanasuri) show")
        p.append(f"68 {y_pos - 46} moveto (Peruntukan Pengguna : Seluruh Dokter, Tenaga Medis, Staf & Pejabat Struktural) show")
        
        # Bottom cover bar
        p.append("0.12 0.35 0.75 setrgbcolor")
        p.append("0 0 595 30 rectfill")
        p.append("1.0 1.0 1.0 setrgbcolor")
        p.append("/Helvetica findfont 9 scalefont setfont")
        p.append("50 11 moveto (Rumah Sakit Khusus Bedah Ropanasuri - Padang | Sistem Informasi Rumah Sakit Terpadu) show")
        
        p.append("showpage")
        self.pages.append("\n".join(p))
        self.page_num += 1

    def _start_content_page(self):
        self.current_page = []
        self.y = 770
        
        # Header bar
        p = self.current_page
        p.append("0.93 0.95 0.98 setrgbcolor")
        p.append("50 790 495 1 rectfill")
        p.append("0.45 0.50 0.60 setrgbcolor")
        p.append("/Helvetica-Bold findfont 8 scalefont setfont")
        p.append(f"50 795 moveto (RSKB ROPANASURI  |  {self.title.upper()}) show")
        p.append("/Helvetica findfont 8 scalefont setfont")
        p.append("450 795 moveto (EDISI OKTOBER 2026) show")
        
    def _finish_content_page(self):
        # Footer
        p = self.current_page
        p.append("0.90 0.92 0.95 setrgbcolor")
        p.append("50 42 495 1 rectfill")
        p.append("0.45 0.50 0.60 setrgbcolor")
        p.append("/Helvetica findfont 8.5 scalefont setfont")
        p.append("50 28 moveto (Sistem Presensi & Manajemen SDM RSKB Ropanasuri) show")
        p.append(f"480 28 moveto (Halaman {self.page_num}) show")
        p.append("showpage")
        self.pages.append("\n".join(p))
        self.page_num += 1
        self._start_content_page()

    def check_space(self, needed):
        if self.y - needed < 55:
            self._finish_content_page()

    def add_section_header(self, num_str, title_text):
        self.check_space(60)
        p = self.current_page
        self.y -= 10
        # Title background
        p.append("0.12 0.35 0.75 setrgbcolor")
        p.append(f"50 {self.y - 4} 495 24 rectfill")
        p.append("1.0 1.0 1.0 setrgbcolor")
        p.append("/Helvetica-Bold findfont 11 scalefont setfont")
        p.append(f"60 {self.y + 3} moveto ({num_str}. {title_text.upper()}) show")
        self.y -= 25

    def add_sub_header(self, sub_text):
        self.check_space(35)
        p = self.current_page
        self.y -= 8
        p.append("0.15 0.45 0.85 setrgbcolor")
        p.append("/Helvetica-Bold findfont 10.5 scalefont setfont")
        p.append(f"50 {self.y} moveto ({sub_text}) show")
        self.y -= 16

    def add_paragraph(self, text, indent=0, font="Helvetica", size=9.5, color="0.20 0.25 0.32", space_after=10):
        avail_width = int((self.width - indent) / (size * 0.52))
        lines = textwrap.wrap(text, width=avail_width)
        needed = len(lines) * (size + 4) + space_after
        self.check_space(needed)
        
        p = self.current_page
        p.append(f"{color} setrgbcolor")
        p.append(f"/{font} findfont {size} scalefont setfont")
        
        for l in lines:
            safe_line = l.replace("(", "[").replace(")", "]")
            p.append(f"{self.margin_left + indent} {self.y} moveto ({safe_line}) show")
            self.y -= (size + 4)
        self.y -= space_after

    def add_bullet(self, bold_prefix, text):
        avail_width = int((self.width - 20) / (9.5 * 0.52))
        full_text = f"{bold_prefix} {text}"
        lines = textwrap.wrap(full_text, width=avail_width)
        needed = len(lines) * 14 + 6
        self.check_space(needed)
        
        p = self.current_page
        p.append("0.15 0.45 0.85 setrgbcolor")
        p.append("/Helvetica-Bold findfont 9.5 scalefont setfont")
        p.append(f"{self.margin_left + 5} {self.y} moveto ([*]) show")
        
        first_line = True
        for l in lines:
            safe_line = l.replace("(", "[").replace(")", "]")
            if first_line:
                p.append("0.15 0.20 0.28 setrgbcolor")
                p.append("/Helvetica findfont 9.5 scalefont setfont")
                p.append(f"{self.margin_left + 22} {self.y} moveto ({safe_line}) show")
                first_line = False
            else:
                p.append("0.25 0.30 0.38 setrgbcolor")
                p.append("/Helvetica findfont 9.5 scalefont setfont")
                p.append(f"{self.margin_left + 22} {self.y} moveto ({safe_line}) show")
            self.y -= 13
        self.y -= 4

    def add_step_card(self, step_num, title, description):
        desc_lines = textwrap.wrap(description, width=68)
        card_height = 28 + len(desc_lines) * 13 + 10
        self.check_space(card_height + 8)
        
        p = self.current_page
        card_y = self.y - card_height
        
        # Background box
        p.append("0.97 0.98 0.99 setrgbcolor")
        p.append(f"50 {card_y} 495 {card_height} rectfill")
        p.append("0.88 0.90 0.94 setrgbcolor")
        p.append(f"50 {card_y} 495 {card_height} rectstroke")
        
        # Left accent stripe
        p.append("0.15 0.45 0.85 setrgbcolor")
        p.append(f"50 {card_y} 4 {card_height} rectfill")
        
        # Number bubble
        bubble_y = self.y - 20
        p.append("0.15 0.45 0.85 setrgbcolor")
        p.append(f"64 {bubble_y} 18 18 rectfill")
        p.append("1.0 1.0 1.0 setrgbcolor")
        p.append("/Helvetica-Bold findfont 9 scalefont setfont")
        p.append(f"69 {bubble_y + 4} moveto ({step_num}) show")
        
        # Step Title
        p.append("0.08 0.12 0.22 setrgbcolor")
        p.append("/Helvetica-Bold findfont 10 scalefont setfont")
        safe_title = title.replace("(", "[").replace(")", "]")
        p.append(f"90 {bubble_y + 4} moveto ({safe_title}) show")
        
        # Step Description lines
        p.append("0.25 0.30 0.38 setrgbcolor")
        p.append("/Helvetica findfont 9 scalefont setfont")
        text_y = bubble_y - 14
        for dl in desc_lines:
            safe_dl = dl.replace("(", "[").replace(")", "]")
            p.append(f"90 {text_y} moveto ({safe_dl}) show")
            text_y -= 13
            
        self.y = card_y - 8

    def add_callout(self, box_type, title, text):
        # types: info (blue), tip (green), warn (amber)
        if box_type == "tip":
            bg = "0.94 0.99 0.96"
            border = "0.72 0.92 0.80"
            stripe = "0.10 0.65 0.35"
            t_color = "0.08 0.45 0.22"
        elif box_type == "warn":
            bg = "1.00 0.98 0.94"
            border = "0.96 0.88 0.70"
            stripe = "0.90 0.55 0.10"
            t_color = "0.65 0.35 0.05"
        else: # info
            bg = "0.94 0.97 1.00"
            border = "0.78 0.88 0.98"
            stripe = "0.15 0.45 0.85"
            t_color = "0.12 0.35 0.75"
            
        lines = textwrap.wrap(text, width=70)
        box_height = 22 + len(lines) * 13 + 8
        self.check_space(box_height + 8)
        
        p = self.current_page
        box_y = self.y - box_height
        
        p.append(f"{bg} setrgbcolor")
        p.append(f"50 {box_y} 495 {box_height} rectfill")
        p.append(f"{border} setrgbcolor")
        p.append(f"50 {box_y} 495 {box_height} rectstroke")
        p.append(f"{stripe} setrgbcolor")
        p.append(f"50 {box_y} 4 {box_height} rectfill")
        
        p.append(f"{t_color} setrgbcolor")
        p.append("/Helvetica-Bold findfont 9.5 scalefont setfont")
        safe_title = title.replace("(", "[").replace(")", "]")
        p.append(f"64 {self.y - 16} moveto ({safe_title}) show")
        
        p.append("0.22 0.28 0.35 setrgbcolor")
        p.append("/Helvetica findfont 9 scalefont setfont")
        ty = self.y - 30
        for l in lines:
            safe_l = l.replace("(", "[").replace(")", "]")
            p.append(f"64 {ty} moveto ({safe_l}) show")
            ty -= 13
            
        self.y = box_y - 8

    def add_table(self, headers, rows, col_widths):
        table_height = 24 + len(rows) * 22 + 10
        self.check_space(table_height)
        
        p = self.current_page
        table_y = self.y
        
        # Header Row
        p.append("0.12 0.35 0.75 setrgbcolor")
        p.append(f"50 {table_y - 20} 495 20 rectfill")
        p.append("1.0 1.0 1.0 setrgbcolor")
        p.append("/Helvetica-Bold findfont 8.5 scalefont setfont")
        
        x = 55
        for idx, h in enumerate(headers):
            safe_h = h.replace("(", "[").replace(")", "]")
            p.append(f"{x} {table_y - 14} moveto ({safe_h}) show")
            x += col_widths[idx]
            
        table_y -= 20
        
        # Rows
        row_idx = 0
        p.append("/Helvetica findfont 8.5 scalefont setfont")
        for row in rows:
            if row_idx % 2 == 1:
                p.append("0.96 0.97 0.99 setrgbcolor")
                p.append(f"50 {table_y - 20} 495 20 rectfill")
                
            p.append("0.88 0.90 0.93 setrgbcolor")
            p.append(f"50 {table_y - 20} 495 20 rectstroke")
            
            p.append("0.18 0.22 0.28 setrgbcolor")
            x = 55
            for idx, cell in enumerate(row):
                safe_cell = cell.replace("(", "[").replace(")", "]")
                p.append(f"{x} {table_y - 14} moveto ({safe_cell}) show")
                x += col_widths[idx]
                
            table_y -= 20
            row_idx += 1
            
        self.y = table_y - 10

    def compile(self):
        # Close last page
        p = self.current_page
        p.append("0.90 0.92 0.95 setrgbcolor")
        p.append("50 42 495 1 rectfill")
        p.append("0.45 0.50 0.60 setrgbcolor")
        p.append("/Helvetica findfont 8.5 scalefont setfont")
        p.append("50 28 moveto (Sistem Presensi & Manajemen SDM RSKB Ropanasuri) show")
        p.append(f"480 28 moveto (Halaman {self.page_num}) show")
        p.append("showpage")
        self.pages.append("\n".join(p))
        
        ps_code = "%!PS-Adobe-3.0\n%%BoundingBox: 0 0 595 842\n%%Pages: " + str(len(self.pages)) + "\n"
        for idx, page in enumerate(self.pages):
            ps_code += f"%%Page: {idx + 1} {idx + 1}\n"
            ps_code += page + "\n"
            
        ps_file = f"{self.filename}.ps"
        pdf_file = f"{self.filename}.pdf"
        
        with open(ps_file, "w") as f:
            f.write(ps_code)
            
        cmd = ["ps2pdf", "-sPAPERSIZE=a4", ps_file, pdf_file]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            sz = round(os.path.getsize(pdf_file) / 1024, 1)
            print(f"SUKSES membuat PDF: {pdf_file} ({sz} KB)")
            os.remove(ps_file)
        else:
            print(f"GAGAL convert PS to PDF: {res.stderr}")

print("Menyiapkan generator dokumen panduan...")

