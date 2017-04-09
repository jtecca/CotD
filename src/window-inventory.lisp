(in-package :cotd)

(defclass inventory-window (window)
  ((cur-tab :initform 0 :accessor cur-tab)
   (cur-inv :initform 0 :accessor cur-inv)))

(defconstant +inv-tab-inv+ 0)
(defconstant +inv-tab-descr+ 1)
(defconstant +inv-tab-char+ 2)

(defmethod make-output ((win inventory-window))
  (fill-background-tiles)

  ;; a pane for inventory
  (sdl:with-rectangle (a-rect (sdl:rectangle :x 10 :y 10 :w 305 :h 435))
    (sdl:fill-surface sdl:*black* :template a-rect))
  ;; a pane for item description
  (sdl:with-rectangle (a-rect (sdl:rectangle :x 325 :y 10 :w 305 :h 225))
    (sdl:fill-surface sdl:*black* :template a-rect))
  ;; a pane for player chars
  (sdl:with-rectangle (a-rect (sdl:rectangle :x 325 :y 245 :w 305 :h 200))
    (sdl:fill-surface sdl:*black* :template a-rect))
  ;; a pane for displaying commands
  (sdl:with-rectangle (a-rect (sdl:rectangle :x 10 :y 455 :w 620 :h 13))
    (sdl:fill-surface sdl:*black* :template a-rect)
    (sdl:with-default-font ((sdl:initialise-default-font sdl:*font-6x13*))
      (sdl:draw-string-solid-* "[d] Drop  [Esc] Exit" 10 455 :color sdl:*white*)))
  
  ;; drawing the inventory list
  (let ((cur-str) (lst (make-list 0)) (color-list (make-list 0)))
    ;(when (= +inv-tab-inv+ (cur-tab win)) (setf selected t))
    (setf cur-str (cur-inv win))
    (dotimes (i (length (inv *player*)))
      (setf lst (append lst (list (name (get-inv-item-by-pos (inv *player*) i)))))
      (if (= i cur-str)  
	  (setf color-list (append color-list (list sdl:*yellow*)))
	  (setf color-list (append color-list (list sdl:*white*)))))
    (draw-selection-list lst cur-str (truncate 425 15) 20 20 color-list))

  ;; drawing selected item description
  ;(when (> (length (inv *player*)) 0)
  ;  (let ((item (get-item-inv (cur-inv win) *player*)))
  ;    (sdl:with-default-font ((sdl:initialise-default-font sdl:*font-6x13*))
  ;	(write-text (get-med-descr item) (sdl:rectangle :x 330 :y 15 :w 295 :h 215)))))

  ;; drawing some player chars
  ;(let ((str (make-array (list 0) :element-type 'character :adjustable t :fill-pointer t)))
  ;  (format str "")
  ;  (when (> (length (weapons *player*)) 0)
  ;    (format str "[Attack]~%")
  ;    (dolist (weapon-params (weapons *player*))
  ;	(format str " ~A-~A (Crit: ~A%)~%" (get-dmg-min-from-list weapon-params) (get-dmg-max-from-list weapon-params) (get-dmg-crit-from-list weapon-params)))
  ;    (format str " Acc: ~A% Spd: ~A~%" (accuracy *player*) (att-spd *player*)))
  ;  
  ;  (when (> (length (ranged *player*)) 0)
  ;    (format str "[Ranged]~%")
  ;    (dolist (weapon-params (ranged *player*))
  ;	(format str " ~A-~A (Crit: ~A%) (Acc: ~A% Spd: ~A)~%" (get-dmg-min-from-list weapon-params) (get-dmg-max-from-list weapon-params) (get-dmg-crit-from-list weapon-params) (get-ranged-acc *player*)
  ;		(get-dmg-speed-from-list weapon-params))))
  ;  
  ;  (format str "[Defense]~%")
  ;  (format str " Dodge: ~A% Block: ~A%~%" (cur-dodge *player*) (cur-block *player*))
  ;  (format str " Protection: ~A Clothing: ~A~%" (cur-armor *player*) (cur-cloth *player*))
    
    ;(when (> (length (armors *player*)) 0)
     ; (format str "[Armor]~%")
  ;;    (dolist (item (armors *player*))
;;	(format str "~A~%" (get-line-descr item)))
      ;(format str "~%"))

    ;(when (> (length (shields *player*)) 0)
     ; (format str "[Shield]~%")
      ;(dolist (item (shields *player*))
;	(format str "~A~%" (get-line-descr item)))
 ;     (format str "~%"))
  ;  
  ;  (sdl:with-default-font ((sdl:initialise-default-font sdl:*font-6x13*))
  ;	(write-text str (sdl:rectangle :x 330 :y 250 :w 295 :h 215))))

  (sdl:update-display))

(defmethod run-window ((win inventory-window))
  (sdl:with-events ()
    (:quit-event () (funcall (quit-func win)) t)
    (:key-down-event (:key key :mod mod :unicode unicode)

                     ;; adjusting the inventory selection
                     (cond
                       ((= (cur-tab win) +inv-tab-inv+) (progn (setf (cur-inv win) (run-selection-list key mod unicode (cur-inv win)))
                                                               (setf (cur-inv win) (adjust-selection-list (cur-inv win) (length (inv *player*)))))))
                     (cond
                       ((sdl:key= key :sdl-key-escape) 
                        (setf *current-window* (return-to win)) (make-output *current-window*) (return-from run-window nil))
                       ((and (sdl:key= key :sdl-key-d) (= mod 0))
                        (clear-message-list *small-message-box*)
                        (mob-drop-item *player* (get-inv-item-by-pos (inv *player*) (cur-inv win)))
                        (setf *current-window* (return-to win))
                        (make-output *current-window*)
                        (return-from run-window nil))
                       ;((and (sdl:key= key :sdl-key-d) (/= (logand mod sdl-cffi::sdl-key-mod-ctrl) 0)) 
                       ; (progn
                       ;   (setf *current-window* (make-instance 'drop-window :return-to *current-window* :item (get-item-inv (cur-inv win) *player*) :act-type :drop))
                       ;   ))
                       ;((sdl:key= key :sdl-key-return) (on-use (get-item-inv (cur-inv win) *player*) *player*))
		       ;  ((and (sdl:key= key :sdl-key-e) (= mod 0)) (eject-ammo *player* (get-item-inv (cur-inv win) *player*)))
                       )
                     (make-output *current-window*)
                     
                     )
    (:video-expose-event () (make-output *current-window*)))
  )