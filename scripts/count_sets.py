#! /usr/bin/env python3
"""
Count cognate sets in the BEAST alignment, and those found only in Formosan languages.

Ascertainment columns (character names ending in "ascertainment") and the concept "above",
which has no partition in the analysis, are not counted. A set is
"found only in Taiwan within the alignment" if every taxon coded 1 for it is Formosan.

Usage:
    python3 count_sets.py nocombining1.xml
"""
import re
import sys

FORMOSAN = """
Bunun_F69_Southern_202 Bunun_Iskubun_805 Bunun_Takbanuaz_804 Bunun_Takituduh_L04_803
Bunun_Takituduh_L88_726 Papora_Ts82_637 Hoanya_Ts82_636 Taokas_Ts82_638 Babuza_Ts82_635
Thao_B96_241 Atayal_Culi_F69_Bandai_256 Atayal_Squliq_F69_255 Atayal_Culi_L04_Mayrinax_742
Atayal_Squliq_L04_819 Atayal_Culi_L04_Skikun_802 Seediq_F69_Sakura_275 Seediq_L04_Paran_820
Seediq_L04_Toda_821 Seediq_L04_Truku_823 Seediq_L04_Hecuo_822 Saisiyat_F69_274
Saisiyat_L04_Taai_818 Saisiyat_L04_Tungho_817 Pazih_LTs_Auran_760 Pazih_F69_266
Kavalan_F69_260 Kavalan_LTs_720 Basay_L04_832 Basay_TsYM91_369 Sakizaya_801 Amis_Central_350
Amis_Farang_800 Amis_Fataan_799 Paiwan_Kulalao_F82_177 Paiwan_Tjatjigel_Egli_1328
Paiwan_Stimul_L04_807 Paiwan_Butanglu_L04_806 Paiwan_Tjubar_L04_808 Puyuma_Chihpen_F69_271
Puyuma_Katipul_L04_811 Puyuma_Lower_Pinlang_L04_810 Puyuma_Nanwang_Cq_759 Puyuma_Pilam_L04_809
Tsou_Duhtu_L04_824 Tsou_T63_138 Saaroa_F69_273 Saaroa_L04_826 Kanakanabu_F69_203
Kanakanabu_L04_825 Rukai_Mantauran_L04_816 Rukai_Tona_815 Rukai_Maga_L04_814
Rukai_Budai_F69_272 Rukai_Tanan_L04_812 Rukai_Budai_L04_813
""".split()


def main():
    text = open(sys.argv[1], encoding="utf-8").read()
    labels = re.findall(r'characterName="([^"]*)"', text)
    seqs = dict(re.findall(r'<sequence [^>]*taxon="([^"]*)"[^>]*value="([^"]*)"', text))
    missing = set(FORMOSAN) - set(seqs)
    if missing:
        sys.exit(f"Formosan taxa not in alignment: {sorted(missing)}")

    total = taiwan_only = taiwan_two_plus = 0
    for i, label in enumerate(labels):
        if label.endswith("ascertainment") or label.startswith("above_"):
            continue
        present = [t for t, s in seqs.items() if s[i] == "1"]
        if not present:
            continue
        total += 1
        if all(t in FORMOSAN for t in present):
            taiwan_only += 1
            if len(present) >= 2:
                taiwan_two_plus += 1

    print(f"Formosan taxa: {len(FORMOSAN)}; all taxa: {len(seqs)}")
    print(f"Cognate sets used: {total}")
    print(f"Found only in Formosan languages: {taiwan_only}")
    print(f"  ... of which in two or more doculects: {taiwan_two_plus}")


if __name__ == "__main__":
    main()
