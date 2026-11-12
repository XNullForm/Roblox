from PIL import Image
import os
O = "export"
combos = [("ua_neutral","m_smile"),("ua_happy","m_grin"),("ua_joy","m_laugh"),("ub_angry","m_grit"),("uc_sad","m_frown"),("uc_wide","m_o"),("ub_think","m_smirk"),("uc_smug","m_smirk"),("ua_tired","m_flat"),("ub_worried","m_wavy")]
sheet = Image.new("RGBA", (256*5, 256*2), (226,182,150,255))
for i,(u,m) in enumerate(combos):
    a = Image.open(os.path.join(O,"face15_%s.png"%u)); b = Image.open(os.path.join(O,"face15_%s.png"%m))
    f = Image.alpha_composite(a,b).crop((96,96,416,416)).resize((256,256), Image.LANCZOS)
    sheet.alpha_composite(f, ((i%5)*256, (i//5)*256))
sheet.save(os.path.join(O,"face15_pv.png"))
