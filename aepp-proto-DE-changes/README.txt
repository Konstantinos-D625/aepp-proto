AEPP Prototype — αλλαγές περιοχής ΔΕ (Area2)
=============================================

Κάνε extract το περιεχόμενο ΠΑΝΩ στον φάκελο του project
(c:\Users\30690\Desktop\aepp-proto), διατηρώντας τη δομή φακέλων.


ΝΕΑ ΑΡΧΕΙΑ
----------
Scenes/BakeryPopup.tscn        Ο Φούρναρης  — popup
Scripts/bakery_popup.gd        Ο Φούρναρης  — λογική (ΜΕ λειτουργικές ασκήσεις)
Scripts/bakery_popup.gd.uid
bakery_quiz.json               Ασκήσεις φούρναρη (προσωρινές, αντικατάστησέ τες)

Scenes/AlchemyPopup.tscn       Ο Αλχημιστής — popup
Scripts/alchemy_popup.gd       Ο Αλχημιστής — λογική (board ΑΔΕΙΟ, με TODO)
Scripts/alchemy_popup.gd.uid

Scenes/LibraryPopup.tscn       Η Βιβλιοθηκάριος — popup
Scripts/library_popup.gd       Η Βιβλιοθηκάριος — λογική (board ΑΔΕΙΟ, με TODO)
Scripts/library_popup.gd.uid


ΤΡΟΠΟΠΟΙΗΜΕΝΟ ΑΡΧΕΙΟ
--------------------
Scenes/Area2.tscn
  + Houses/Bakery   (0, 1100) - (450, 1670)   -> BakeryPopup
  + Houses/Alchemy  (700, 500) - (1080, 1150) -> AlchemyPopup
  + Houses/Library  (0, 505)  - (380, 1085)   -> LibraryPopup
  + Houses/Shop     (380, 160) - (660, 720)   -> ShopPopup  (το ΙΔΙΟ της ΔΑ)
  + instances: BakeryPopup, AlchemyPopup, LibraryPopup, ShopPopup
  Τα τέσσερα hitboxes ΔΕΝ επικαλύπτονται (επαληθεύτηκε αυτόματα).


ΔΕΝ ΠΕΡΙΛΑΜΒΑΝΟΝΤΑΙ (και δεν χρειάζονται)
-----------------------------------------
- Οι εικόνες (bakery.bg/bg2, alch.bg/bg2, library.bg/bg2) — τις έχεις ήδη
  στον φάκελο Εικόνες/. Τα .import αρχεία τα ξαναφτιάχνει μόνο του το Godot.
- Scenes/ShopPopup.tscn, Scripts/shop_popup.gd — ΔΕΝ αγγίχτηκαν καθόλου.
  Η ΔΕ κάνει instance την ίδια ακριβώς σκηνή με τη ΔΑ.
- project.godot — ΔΕΝ άλλαξε.


ΠΟΥ ΜΠΑΙΝΟΥΝ ΟΙ ΑΣΚΗΣΕΙΣ
------------------------
Αλχημιστής / Βιβλιοθηκάριος:
  στη συνάρτηση _populate_board(), στο σημείο με το σχόλιο
  "TODO: εδώ μπαίνουν οι ασκήσεις".
  Προσθέτεις Control στο _board_content, π.χ.:
      _board_content.add_child(_make_board_label("Η εκφώνηση..."))
      _board_content.add_child(_make_answer_button("ΣΩΣΤΟ", C_OK))
  Σβήσε το προσωρινό placeholder label από κάτω.

Φούρναρης:
  αλλάζεις ΜΟΝΟ το bakery_quiz.json — ο κώδικας δεν θέλει αλλαγή.
  Μορφή: { "question": "...", "answer": "ΣΩΣΤΟ", "difficulty": 2 }

Πλήρες λειτουργικό παράδειγμα σύνδεσης με QuizManager: bakery_popup.gd


ΚΕΙΜΕΝΑ NPC
-----------
Φούρναρης       bakery_popup.gd    (~γρ. 205)
Αλχημιστής      alchemy_popup.gd   (~γρ. 253)
Βιβλιοθηκάριος  library_popup.gd   (~γρ. 300)
Όριο ~6 γραμμές το καθένα — πιο κάτω η φούσκα σκεπάζει το πρόσωπο του NPC.
