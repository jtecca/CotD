(in-package :cotd)

(defclass cell-window (window)
  ((shoot-mode :initform :single :accessor shoot-mode)
   (idle-calcing :initform :done :accessor idle-calcing) ; :done - background pathfinding calculation finished
                                                         ; :in-progress - background pathfinding calculation in progress
                                                         ; :npc-turn - it is not players turn
   ))

(defun show-char-effects (mob x y h)
  (loop for effect being the hash-key in (effects mob)
        with y1 = y    
        do
           (when (> (+ y1 (sdl:get-font-height)) (+ y h))
             (sdl:draw-string-solid-* "(...)" x y1 :color sdl:*white*)
             (loop-finish))
             (cond
               ((= effect +mob-effect-possessed+) (sdl:draw-string-solid-* "Possession" x y1 :color sdl:*red*))
               ((= effect +mob-effect-blessed+) (sdl:draw-string-solid-* "Blessed" x y1 :color sdl:*blue*))
               ((= effect +mob-effect-reveal-true-form+) (sdl:draw-string-solid-* "Revealed" x y1 :color sdl:*red*))
               ((= effect +mob-effect-divine-consealed+) (sdl:draw-string-solid-* "Consealed" x y1 :color sdl:*cyan*))
               ((= effect +mob-effect-calling-for-help+) (sdl:draw-string-solid-* "Summoning" x y1 :color sdl:*green*))
               ((= effect +mob-effect-called-for-help+) (sdl:draw-string-solid-* "Called" x y1 :color sdl:*green*))
               ((= effect +mob-effect-divine-shield+) (sdl:draw-string-solid-* "Divine shield" x y1 :color sdl:*yellow*))
               ((= effect +mob-effect-cursed+) (sdl:draw-string-solid-* "Cursed" x y1 :color (sdl:color :r 139 :g 69 :b 19))))
             (incf y1 (sdl:get-font-height))))

(defun show-char-properties (x y idle-calcing)
  (let* ((str)
         (str-lines))
    (sdl:with-rectangle (a-rect (sdl:rectangle :x x :y y :w 250 :h (* *glyph-h* *max-y-view*)))
      (sdl:fill-surface sdl:*black* :template a-rect)
      (setf str (format nil "~A - ~A~%~%HP: ~A/~A~%Power: ~A/~A~%~%~A~%~%Humans ~A~%Blessed ~A~%Angels ~A~%Demons ~A~%~%~A~%"
                        (name *player*) (name (get-mob-type-by-id (mob-type *player*)))
                        (cur-hp *player*) (max-hp *player*) 
                        (cur-fp *player*) (max-fp *player*)
                        (get-weapon-descr-line *player*)
                        (total-humans *world*)
                        (total-blessed *world*)
                        (total-angels *world*)
                        (total-demons *world*)
                        (sense-good-evil-str)
                      ))
      (setf str-lines (write-text  str a-rect :color sdl:*white*)))
    (show-char-effects *player* x (+ y (* (sdl:get-font-height) (1+ str-lines))) 52)
    (show-time-label idle-calcing x (+ y 237))
    ))

(defun show-small-message-box (x y w &optional (h *msg-box-window-height*))
  (sdl:with-rectangle (a-rect (sdl:rectangle :x x :y y :w w :h h))
    (sdl:fill-surface sdl:*black* :template a-rect)) 
  (let ((max-lines (write-text (get-msg-str-list) (sdl:rectangle :x x :y y :w w :h h) :count-only t)))
    (when (> (message-list-length) 0)
      (write-text (get-msg-str-list) (sdl:rectangle :x x :y y :w w :h h) :start-line (if (< (truncate h (sdl:char-height sdl:*default-font*)) max-lines)
                                                                                       (- max-lines (truncate h (sdl:char-height sdl:*default-font*)))
                                                                                       0)))))

(defun sense-good-evil-str ()
  (let ((str (create-string)))
    (when (sense-evil-id *player*)
      (format str "Sense evil: ~A~%" (general-direction-str (x *player*) (y *player*) (x (get-mob-by-id (sense-evil-id *player*))) (y (get-mob-by-id (sense-evil-id *player*))))))
    (when (sense-good-id *player*)
      (format str "Sense good: ~A~%" (general-direction-str (x *player*) (y *player*) (x (get-mob-by-id (sense-good-id *player*))) (y (get-mob-by-id (sense-good-id *player*))))))
    str))

(defun general-direction-str (sx sy tx ty)
  (let ((a (round (* (atan (- sy ty) (- sx tx)) (/ 180 pi))))
        (result))
    (cond
      ((and (> a 22.5) (<= a 67.5)) (setf result "NW"))
      ((and (> a 67.5) (<= a 112.5)) (setf result "N"))
      ((and (> a 112.5) (<= a 157.5)) (setf result "NE"))
      ((and (< a -22.5) (>= a -67.5)) (setf result "SW"))
      ((and (< a -67.5) (>= a -112.5)) (setf result "S"))
      ((and (< a -112.5) (>= a -157.5)) (setf result "SE"))
      ((or (> a 157.5) (< a -157.5)) (setf result "E"))
      ((or (> a -22.5) (<= a 22.5)) (setf result "W")))
    result))

(defun update-screen (win)
  
  ;; filling the background with black rectangle
  (fill-background-tiles)
   
  (update-map-area)
    
  (show-char-properties (+ 20 (* *glyph-w* *max-x-view*)) 10 (idle-calcing win))
  (show-small-message-box *glyph-w* (+ 20 (* *glyph-h* *max-y-view*)) (+ 250 (+ 10 (* *glyph-w* *max-x-view*))))
    
  (sdl:update-display)
  
 )

(defmethod make-output ((win cell-window))
  
  (update-screen win)
  )

(defmethod run-window ((win cell-window))

  (tagbody
     (sdl:with-events ()
       (:quit-event () (funcall (quit-func *current-window*)) t)
       (:key-down-event (:key key :mod mod :unicode unicode)
                        (declare (ignore unicode))
                        ;;------------------
			;; moving - arrows
			(when (or (sdl:key= key :sdl-key-pageup) (sdl:key= key :sdl-key-kp9))
                          (if (can-move-if-possessed *player*)
                            (setf (can-move-if-possessed *player*) nil)
                            (move-mob *player* 9)
                            )
                          )
			(when (or (sdl:key= key :sdl-key-up) (sdl:key= key :sdl-key-kp8))
                          (if (can-move-if-possessed *player*)
                            (setf (can-move-if-possessed *player*) nil)
                            (move-mob *player* 8)
                            )
                          )
			(when (or (sdl:key= key :sdl-key-home) (sdl:key= key :sdl-key-kp7))
                          (if (can-move-if-possessed *player*)
                            (setf (can-move-if-possessed *player*) nil)
                            (move-mob *player* 7)
                            )
                          )
			(when (or (sdl:key= key :sdl-key-right) (sdl:key= key :sdl-key-kp6))
                          (if (can-move-if-possessed *player*)
                            (setf (can-move-if-possessed *player*) nil)
                            (move-mob *player* 6)
                            )
                          )
			(when (sdl:key= key :sdl-key-kp5)
                          (if (can-move-if-possessed *player*)
                            (setf (can-move-if-possessed *player*) nil)
                            (move-mob *player* 5)
                            )
                          )
			(when (or (sdl:key= key :sdl-key-left) (sdl:key= key :sdl-key-kp4))
                          (if (can-move-if-possessed *player*)
                            (setf (can-move-if-possessed *player*) nil)
                            (move-mob *player* 4)
                            )
                          )
			(when (or (sdl:key= key :sdl-key-pagedown) (sdl:key= key :sdl-key-kp3))
                          (if (can-move-if-possessed *player*)
                            (setf (can-move-if-possessed *player*) nil)
                            (move-mob *player* 3)
                            )
                          )
			(when (or (sdl:key= key :sdl-key-down) (sdl:key= key :sdl-key-kp2))
                          (if (can-move-if-possessed *player*)
                            (setf (can-move-if-possessed *player*) nil)
                            (move-mob *player* 2)
                            )
                          )
			(when (or (sdl:key= key :sdl-key-end) (sdl:key= key :sdl-key-kp1))
                          (if (can-move-if-possessed *player*)
                            (setf (can-move-if-possessed *player*) nil)
                            (move-mob *player* 1)
                            )
                          )
			;;------------------
			;; character mode - Shift + 2
			(when (and (sdl:key= key :sdl-key-2) (/= (logand mod sdl-cffi::sdl-key-mod-shift) 0))
			  (setf *current-window* (make-instance 'character-window :return-to *current-window*)))
                        ;;------------------
			;; help screen - ?
			(when (or (sdl:key= key :sdl-key-question)
                                  (and (sdl:key= key :sdl-key-slash) (/= (logand mod sdl-cffi::sdl-key-mod-shift) 0))
                                  (and (sdl:key= key :sdl-key-7) (/= (logand mod sdl-cffi::sdl-key-mod-shift) 0)))
			  (setf *current-window* (make-instance 'help-window :return-to *current-window*)))		
                        ;;------------------
			;; select abilities - a
                        (when (and (sdl:key= key :sdl-key-a))
                          (let ((abil-name-list nil)
                                (abil-descr-list nil)
                                (abil-prompt-list nil)
                                (mob-abilities (get-mob-all-abilities *player*)))
                            
                            ;; filter ability list to leave only non passive and applicable
                            (setf mob-abilities (loop for ability-type-id in mob-abilities
                                                      when (and (not (abil-passive-p ability-type-id))
                                                                (abil-applicable-p (get-ability-type-by-id ability-type-id) *player* *player*))
                                                        collect ability-type-id))
                            (if mob-abilities
                              (progn
                                ;; populate the ability name list 
                                (setf abil-name-list
                                      (loop
                                        for ability-type-id in mob-abilities
                                        collect (name (get-ability-type-by-id ability-type-id))))

                                ;; populate the ability description list
                                (setf abil-descr-list
                                      (loop
                                        for ability-type-id in mob-abilities
                                        collect (if (abil-applic-cost-p ability-type-id *player*)
                                                  (format nil "Cost: ~A. TU: ~A." (cost (get-ability-type-by-id ability-type-id)) (spd (get-ability-type-by-id ability-type-id)))
                                                  (format nil "Cost: ~A. Insufficient power!" (cost (get-ability-type-by-id ability-type-id))))))

                                ;; populate the ability prompt list
                                (setf abil-prompt-list
                                      (loop
                                        for ability-type-id in mob-abilities
                                        collect #'(lambda (cur-sel)
                                                    (if (can-invoke-ability *player* *player* (nth cur-sel mob-abilities))
                                                      "[Enter] Invoke  [Escape] Cancel"
                                                      "[Escape] Cancel"))))
                                
                                ;; display the window with the list
                                (setf *current-window* (make-instance 'select-obj-window 
                                                                      :return-to *current-window* 
                                                                      :obj-list abil-name-list
                                                                      :descr-list abil-descr-list
                                                                      :enter-func #'(lambda (cur-sel)
                                                                                      (when (can-invoke-ability *player* *player* (nth cur-sel mob-abilities))
                                                                                        (mob-invoke-ability *player* *player* (nth cur-sel mob-abilities))
                                                                                        (setf *current-window* win)
                                                                                        (set-idle-calcing win)
                                                                                        (show-time-label (idle-calcing win) (+ 20 (* *glyph-w* *max-x-view*)) (+ 10 237) t)
                                                                                        )
                                                                                        )
                                                                      :line-list abil-name-list
                                                                      :prompt-list abil-prompt-list)))
                              (progn
                                ;; no abilites - display a message
                                (add-message (format nil "You have no abilities to invoke.~%"))
                                ))
			    ))
			;;------------------
			;; look mode - l
			(when (and (sdl:key= key :sdl-key-l) (= mod 0))
			  (setf *current-window* (make-instance 'map-select-window 
								:return-to *current-window*
								:cmd-str ""
								:exec-func #'(lambda ()
									       nil)))
			  (make-output *current-window*))
                        ;;------------------
			;; view messages - m
                        (when (and (sdl:key= key :sdl-key-m) (= mod 0))
			  (setf *current-window* (make-instance 'message-window 
								:return-to *current-window*))
								
			  (make-output *current-window*))
			
			(set-idle-calcing win)

                        
			(make-output *current-window*)
			(go exit-loop)
                        )
       (:idle () #+swank(update-swank)
              
                 (set-idle-calcing win)

                 (show-time-label (idle-calcing win) (+ 20 (* *glyph-w* *max-x-view*)) (+ 10 237) t)
              )
              
       (:video-expose-event () (make-output *current-window*)))
    exit-loop)
  nil)

(defmacro continuable (&body body)
  "Helper macro that we can use to allow us to continue from an error. Remember to hit C in slime or pick the restart so errors don't kill the app."
  `(restart-case (progn ,@body) (continue () :report "Continue")))

#+swank
(defun update-swank ()
       "Called from within the main loop, this keep the lisp repl working while the game runs"
  (continuable (let ((connection (or swank::*emacs-connection* (swank::default-connection))))
                 (when connection
                   (swank::handle-requests connection t)))))

(defun show-time-label (idle-calcing x y &optional (update nil))
  (sdl:draw-string-solid-* (format nil "Time ~A"  (player-game-time *world*))
                           x y :color (cond ((eql idle-calcing :done) sdl:*white*)
                                            ((eql idle-calcing :in-progress) sdl:*yellow*)
                                            ((eql idle-calcing :npc-turn) sdl:*red*)))
  (when update
    (sdl:update-display)))

(defun set-idle-calcing (win)
  (if (made-turn *player*)
    (setf (idle-calcing win) :npc-turn)
    (if (< (cur-mob-path *world*) (length (mob-id-list (level *world*))))
      (setf (idle-calcing win) :in-progress)
      (setf (idle-calcing win) :done))))


