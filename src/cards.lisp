(in-package :cotd)

(defconstant +item-card-blink+ 0)
(defconstant +item-card-teleport+ 1)
(defconstant +item-card-disguise+ 2)
(defconstant +item-card-sprint+ 3)
(defconstant +item-card-flying+ 4)
(defconstant +item-card-curse-other+ 5)
(defconstant +item-card-blindness-other+ 6)
(defconstant +item-card-fear-other+ 7)
(defconstant +item-card-slow-other+ 8)
(defconstant +item-card-silence-other+ 9)
(defconstant +item-card-confuse-other+ 10)
(defconstant +item-card-polymorph-other+ 11)
(defconstant +item-card-polymorph-self+ 12)
(defconstant +item-card-irradiate-other+ 13)
(defconstant +item-card-irradiate-self+ 14)
(defconstant +item-card-confuse-self+ 15)
(defconstant +item-card-silence-self+ 16)
(defconstant +item-card-slow-self+ 17)
(defconstant +item-card-fear-self+ 18)
(defconstant +item-card-blindness-self+ 19)
(defconstant +item-card-curse-self+ 20)
(defconstant +item-card-give-deck+ 21)
(defconstant +item-card-glowing-all+ 22)

(defclass card-type ()
  ((id :initarg :id :accessor id)
   (name :initform "Unnamed card" :initarg :name :accessor name)
   (on-use :initform #'(lambda (card-type actor)
                         (declare (ignore card-type actor))
                         nil)
           :initarg :on-use :accessor on-use)
   ))

(defun get-card-type-by-id (card-type-id)
  (aref *card-types* card-type-id))

(defun set-card-type (card-type)
  (when (>= (id card-type) (length *card-types*))
    (adjust-array *card-types* (list (1+ (id card-type)))))
  (setf (aref *card-types* (id card-type)) card-type))
