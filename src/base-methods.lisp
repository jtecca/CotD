(in-package :cotd)

(defun find-free-id (array)
  (loop for i from 0 below (length array)
        unless (aref array i)
          do (return-from find-free-id i))
  (adjust-array array (list (1+ (length array))))
  (1- (length array)))

(defun capitalize-name (str)
  (string-upcase str :start 0 :end 1))

(defun x-y-into-dir (x y)
  (let ((xy (list x y)))
    (cond
      ((equal xy '(-1 1)) 1)
      ((equal xy '(0 1)) 2)
      ((equal xy '(1 1)) 3)
      ((equal xy '(-1 0)) 4)
      ((equal xy '(0 0)) 5)
      ((equal xy '(1 0)) 6)
      ((equal xy '(-1 -1)) 7)
      ((equal xy '(0 -1)) 8)
      ((equal xy '(1 -1)) 9)
      (t nil))))

(defun x-y-into-str (xy-cons)
  (cond
    ((equal xy-cons '(-1 . 1)) "SW")
    ((equal xy-cons '(0 . 1)) "S")
    ((equal xy-cons '(1 . 1)) "SE")
    ((equal xy-cons '(-1 . 0)) "W")
    ((equal xy-cons '(0 . 0)) "None")
    ((equal xy-cons '(1 . 0)) "E")
    ((equal xy-cons '(-1 . -1)) "NW")
    ((equal xy-cons '(0 . -1)) "N")
    ((equal xy-cons '(1 . -1)) "NE")
    (t "ERR")))

(defun x-y-dir (dir)
  "Determine the x-y coordinate change from the single number specifying direction"
  (cond
    ((eql dir 1) (values-list '(-1 1)))
    ((eql dir 2) (values-list '(0 1)))
    ((eql dir 3) (values-list '(1 1)))
    ((eql dir 4) (values-list '(-1 0)))
    ((eql dir 5) (values-list '(0 0)))
    ((eql dir 6) (values-list '(1 0)))
    ((eql dir 7) (values-list '(-1 -1)))
    ((eql dir 8) (values-list '(0 -1)))
    ((eql dir 9) (values-list '(1 -1)))
    (t (error "Wrong direction supplied!!!"))))

(defun dir-neighbours (dir)
  ;; find the neighbours of the direction
  ;; the result is <along the direction> <not along the direction> <to the left from the direction> <to the right from the direction> <near the opposite direction> <opposite the direction>
  ;; for more info see the move-mob func
  (cond
    ((eql dir 1) (values-list '((4 1 2) (3 6 7 8) (3 6) (7 8) (8 6) (9))))
    ((eql dir 2) (values-list '((1 2 3) (4 6 7 9) (6 9) (4 7) (7 9) (8))))
    ((eql dir 3) (values-list '((2 3 6) (1 4 8 9) (9 8) (1 4) (4 8) (7))))
    ((eql dir 4) (values-list '((1 4 7) (8 2 9 3) (2 3) (8 9) (9 3) (6))))
    ((eql dir 5) (values-list '((1 2 3 4 5 6 7 8 9) () () () () ())))
    ((eql dir 6) (values-list '((9 6 3) (8 2 7 1) (8 7) (2 1) (7 1) (4))))
    ((eql dir 7) (values-list '((4 7 8) (1 9 2 6) (1 2) (9 3) (6 2) (3))))
    ((eql dir 8) (values-list '((7 8 9) (4 6 1 3) (4 1) (6 3) (1 3) (2))))
    ((eql dir 9) (values-list '((8 9 6) (7 3 4 2) (7 4) (3 2) (4 2) (1))))
    (t (error "Wrong direction supplied!!!"))))

(defun check-surroundings (x y include-center func)
  (dotimes (x1 3)
    (dotimes (y1 3)
      (when include-center
	(funcall func (+ (1- x) x1) (+ (1- y) y1)))
      (when (and (eql include-center nil)
		 (or (/= (+ (1- x) x1) x) (/= (+ (1- y) y1) y)))
	(funcall func (+ (1- x) x1) (+ (1- y) y1))))))

(defun check-surroundings-3d (x y z include-center func)
  (loop for dx from -1 to 1 do
    (loop for dy from -1 to 1 do
      (loop for dz from -1 to 1 do
        (cond
          ((and include-center
                (= dx dy dz 0))
           (funcall func (+ x dx) (+ y dy) (+ z dz)))
          ((and (not include-center)
                (= dx dy dz 0))
           nil)
          (t (funcall func (+ x dx) (+ y dy) (+ z dz))))))))
  

(defun print-visible-message (x y z level str &key (observed-mob nil))
  (when (or (and (null observed-mob)
                 (get-single-memo-visibility (get-memo-* level x y z)))
            (and observed-mob
                 (get-single-memo-visibility (get-memo-* level x y z))
                 (check-mob-visible observed-mob :observer *player* :complete-check t)))
    (set-message-this-turn t)
    (add-message str)))

(defun place-animation (x y z animation-type-id &key (params nil))
  (push (make-animation :id animation-type-id :x x :y y :z z :params params) (animation-queue *world*)))

(defun check-move-on-level (mob dx dy dz)
  (let ((sx) (sy)
        (mob-list nil)
        (obst-list nil))
    ;; calculate the coords of the mob's NE corner
    (setf sx (- dx (truncate (1- (map-size mob)) 2)))
    (setf sy (- dy (truncate (1- (map-size mob)) 2)))

    (loop for nx from sx below (+ sx (map-size mob)) do
      (loop for ny from sy below (+ sy (map-size mob)) do
        ;; trying to move beyound the level border 
        (when (or (< nx 0) (< ny 0) (>= nx *max-x-level*) (>= ny *max-y-level*))
          (return-from check-move-on-level nil))
        
        ;; checking for obstacle
        (when (get-terrain-type-trait (get-terrain-* (level *world*) nx ny dz) +terrain-trait-blocks-move+)
          ;(return-from check-move-on-level nil)
          (pushnew (list nx ny dz) obst-list)
          )

        (when obst-list
          (return-from check-move-on-level (list :obstacles obst-list)))
        
        ;; checking for mobs
        (when (and (get-mob-* (level *world*) nx ny dz)
                   (not (eq (get-mob-* (level *world*) nx ny dz) mob))
                   (or (eq (mounted-by-mob-id mob) nil)
                       (not (eq (mounted-by-mob-id mob) (id (get-mob-* (level *world*) nx ny dz))))))
          (pushnew (get-mob-* (level *world*) nx ny dz) mob-list)
          )))

    (when mob-list
      (return-from check-move-on-level (list :mobs mob-list)))
    
    ;; all checks passed - can move freely
    (return-from check-move-on-level t)))

(defun check-move-along-z (sx sy sz dx dy dz)
  (cond
    ;; move down
    ((< (- dz sz) 0) (progn
                            (if (and (>= dz 0)
                                     (not (get-terrain-type-trait (get-terrain-* (level *world*) dx dy (1+ dz)) +terrain-trait-opaque-floor+))
                                     )
                              t
                              nil)))
    ;; move up
    ((> (- dz sz) 0) (progn
                            (if (and (< dz (array-dimension (terrain (level *world*)) 2))
                                     (not (get-terrain-type-trait (get-terrain-* (level *world*) sx sy dz) +terrain-trait-opaque-floor+))
                                     )
                              t
                              nil)))
    ;; no vertical movement
    (t t)))

(defmethod apply-gravity ((mob mob))
  (let ((result 0))
    (if (and (mob-effect-p mob +mob-effect-flying+)
             (not (eq (cd (get-effect-by-id (mob-effect-p mob +mob-effect-flying+))) 0)))
      (setf result (z mob))
      (loop for z from (z mob) downto 0 
            for check-result = (check-move-on-level mob (x mob) (y mob) z)
            do
             ;(format t "Z ~A FLOOR ~A~%" z (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) z) +terrain-trait-opaque-floor+))
               (when (eq check-result t)
                 (setf result z))
               
             ;(format t "MOB ~A, Z = ~A, Z MOB = ~A, WATER = ~A~%" (name mob) z (z mob) (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) z) +terrain-trait-water+))
               
               ;; stop falling if
               (when (or (not (eq check-result t))
                         ;; if there is water in the current tile
                         (and (/= z (z mob))
                              (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) z) +terrain-trait-water+)
                              )
                         ;; there is floor on this tile
                         (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) z) +terrain-trait-opaque-floor+)
                         ;; there is no floor on this tile, but the mob is in climbing mode and there is a wall or a floor nearby
                         (and (not (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) z) +terrain-trait-opaque-floor+))
                              (mob-effect-p mob +mob-effect-climbing-mode+)
                              (funcall #'(lambda ()
                                           (let ((result nil))
                                             (check-surroundings (x mob) (y mob) nil #'(lambda (dx dy)
                                                                                         (when (and (not (get-terrain-type-trait (get-terrain-* (level *world*) dx dy z) +terrain-trait-not-climable+))
                                                                                                    (or (get-terrain-type-trait (get-terrain-* (level *world*) dx dy z) +terrain-trait-opaque-floor+)
                                                                                                        (get-terrain-type-trait (get-terrain-* (level *world*) dx dy z) +terrain-trait-blocks-move+)))
                                                                                           (setf result t))))
                                             result))))
                         )
                 (loop-finish))))
    (when (eq result (z mob))
      (setf result nil))

    result))

(defmethod apply-gravity ((feature feature))
  (let ((result 0))
    (loop for z from (z feature) downto 0 
          do
             (when (or (get-terrain-type-trait (get-terrain-* (level *world*) (x feature) (y feature) z) +terrain-trait-opaque-floor+)
                       (get-terrain-type-trait (get-terrain-* (level *world*) (x feature) (y feature) z) +terrain-trait-water+))
               (setf result z)
               (loop-finish)))
    (when (eq result (z feature))
      (setf result nil))
    result))

(defmethod apply-gravity ((item item))
  (let ((result 0))
    (loop for z from (z item) downto 0 
          do
             (when (or (get-terrain-type-trait (get-terrain-* (level *world*) (x item) (y item) z) +terrain-trait-opaque-floor+)
                       (and (>= (1- z) 0)
                            (get-terrain-type-trait (get-terrain-* (level *world*) (x item) (y item) (1- z)) +terrain-trait-blocks-move+)))
               (setf result z)
               (loop-finish)))
    (when (eq result (z item))
      (setf result nil))
    result))
      

(defun generate-sound (source-mob sx sy sz sound-power str-func &key (force-sound nil))
  (when (zerop sound-power)
    (return-from generate-sound nil))
  (loop for mob-id in (hear-range-mobs source-mob)
        for tmob = (get-mob-by-id mob-id)
        do
           (propagate-sound-from-location tmob sx sy sz sound-power str-func
                                          :source source-mob :force-sound force-sound)))

(defun set-mob-location (mob x y z &key (apply-gravity t))
  (logger (format nil "SET-MOB-LOCATION BEFORE: ~A [~A] (~A ~A ~A) to (~A ~A ~A) gravity = ~A~%" (name mob) (id mob) (x mob) (y mob) (z mob) x y z apply-gravity))
  (let ((place-func #'(lambda (nmob)
                        (let ((sx) (sy))
                          ;; calculate the coords of the mob's NE corner
                          (setf sx (- (x nmob) (truncate (1- (map-size nmob)) 2)))
                          (setf sy (- (y nmob) (truncate (1- (map-size nmob)) 2)))
                          
                          ;; remove the mob from the orignal position
                          ;; for size 1 (standard) mobs the loop executes only once, so it devolves into traditional movement 
                          (loop for nx from sx below (+ sx (map-size nmob)) do
                            (loop for ny from sy below (+ sy (map-size nmob)) do
                              (when (on-step (get-terrain-type-by-id (get-terrain-* (level *world*) nx ny (z nmob))))
                                (funcall (on-step (get-terrain-type-by-id (get-terrain-* (level *world*) nx ny (z nmob)))) nmob nx ny (z nmob)))
                              (setf (aref (mobs (level *world*)) nx ny (z nmob)) nil)))
                          
                          ;; change the coords of the center of the mob
                          (setf (x nmob) x (y nmob) y (z nmob) z)
                          
                          ;; calculate the new coords of the mob's NE corner
                          (setf sx (- (x nmob) (truncate (1- (map-size nmob)) 2)))
                          (setf sy (- (y nmob) (truncate (1- (map-size nmob)) 2)))
                          
                          ;; place the mob to the new position
                          ;; for size 1 (standard) mobs the loop executes only once, so it devolves into traditional movement
                          (loop for nx from sx below (+ sx (map-size nmob)) do
                            (loop for ny from sy below (+ sy (map-size nmob)) do
                              (setf (aref (mobs (level *world*)) nx ny z) (id nmob))
                              
                              (when (on-step (get-terrain-type-by-id (get-terrain-* (level *world*) nx ny z)))
                                (funcall (on-step (get-terrain-type-by-id (get-terrain-* (level *world*) nx ny z))) nmob nx ny z)))))))
        (orig-x (x mob))
        (orig-y (y mob))
        (orig-z (z mob)))

    ;; we have 3 cases of movement:
    ;; 1) the mob moves while is riding someone (currently available if the mob teleports somewhere with a mount, as normally the rider does not move, only gives directions to the mount)
    ;; 2) the mob moves while being ridden by someone (all kinds of mounted movement)
    ;; 3) the mob moves by itself
    (cond
      ((riding-mob-id mob)
       (progn
         ;; it is imperative the a 1-tile mob rides a multi-tile mob and not vice versa

         (if (and (= (x (get-mob-by-id (riding-mob-id mob))) x) (= (y (get-mob-by-id (riding-mob-id mob))) y) (= (z (get-mob-by-id (riding-mob-id mob))) z))
           (incf-mob-motion (get-mob-by-id (riding-mob-id mob)) *mob-motion-stand*)
           (incf-mob-motion (get-mob-by-id (riding-mob-id mob)) *mob-motion-move*))

         ;; remove the rider from the prev location 
         (setf (aref (mobs (level *world*)) (x mob) (y mob) (z mob)) nil)
         
         (funcall place-func (get-mob-by-id (riding-mob-id mob)))

         ;; place the rider
         (setf (x mob) x (y mob) y (z mob) z)
         (setf (aref (mobs (level *world*)) x y z) (id mob))

          ;; set motion
         (if (and (= orig-x x) (= orig-y y) (= orig-z z))
           (incf-mob-motion mob *mob-motion-stand*)
           (incf-mob-motion mob *mob-motion-move*))
         
         ))
      ((mounted-by-mob-id mob)
       (progn
         ;; it is imperative the a 1-tile mob rides a multi-tile mob and not vice versa

         (let ((rider-orig-x (x (get-mob-by-id (mounted-by-mob-id mob))))
               (rider-orig-y (y (get-mob-by-id (mounted-by-mob-id mob))))
               (rider-orig-z (z (get-mob-by-id (mounted-by-mob-id mob)))))

           ;; remove the rider from the prev location 
           (setf (aref (mobs (level *world*)) rider-orig-x rider-orig-y rider-orig-z) nil)
           
           (funcall place-func mob)
           
           ;; place the rider
           (setf (x (get-mob-by-id (mounted-by-mob-id mob))) x
                 (y (get-mob-by-id (mounted-by-mob-id mob))) y
                 (z (get-mob-by-id (mounted-by-mob-id mob))) z)
           (setf (aref (mobs (level *world*)) (x mob) (y mob) (z mob)) (mounted-by-mob-id mob))
           
           ;; set motion
           (if (and (= orig-x x) (= orig-y y) (= orig-z z))
             (incf-mob-motion mob *mob-motion-stand*)
             (incf-mob-motion mob *mob-motion-move*))
           
           (if (and (= rider-orig-x x) (= rider-orig-y y) (= rider-orig-z z))
             (progn
               (incf-mob-motion (get-mob-by-id (mounted-by-mob-id mob)) *mob-motion-stand*)
               
               ;; generate sound
               (generate-sound (get-mob-by-id (mounted-by-mob-id mob)) x y z *mob-sound-stand* #'(lambda (str)
                                                                                                   (format nil "You hear some scratching~A. " str))))
             (progn
               (incf-mob-motion (get-mob-by-id (mounted-by-mob-id mob)) *mob-motion-move*)
               
               ;; generate sound
               (generate-sound (get-mob-by-id (mounted-by-mob-id mob)) x y z *mob-sound-move* #'(lambda (str)
                                                                                                  (format nil "You hear rustling~A. " str)))
               ))
           
           
           )))
      (t
       (progn
                 
         (funcall place-func mob)
         
          ;; set motion
         (if (and (= orig-x x) (= orig-y y) (= orig-z z))
           (progn
             (incf-mob-motion mob *mob-motion-stand*)

             ;; generate sound
             (generate-sound mob x y z *mob-sound-stand* #'(lambda (str)
                                                             (format nil "You hear some scratching~A. " str))))
           (progn
             (incf-mob-motion mob *mob-motion-move*)

             ;; generate sound
             (generate-sound mob x y z *mob-sound-move* #'(lambda (str)
                                                            (format nil "You hear rustling~A. " str)))
             ))
         )))

    ;; apply gravity
    (when (and apply-gravity
               (apply-gravity mob))
      (let ((init-z (z mob)) (cur-dmg 0))
        (set-mob-location mob (x mob) (y mob) (apply-gravity mob) :apply-gravity nil)
        (setf cur-dmg (* 5 (1- (- init-z (z mob)))))
        (decf (cur-hp mob) cur-dmg)
        (when (> cur-dmg 0)
          (if (eq mob *player*)
            (progn
              ;; a hack because sometimes the player may fall somewhere he does not see (when riding a horse for example) and then no message will be displayed normally 
              (set-message-this-turn t)
              (add-message (format nil "~A falls and takes ~A damage. " (capitalize-name (prepend-article +article-the+ (visible-name mob))) cur-dmg))
              (when (check-dead mob) (setf (killed-by *player*) "falling")))
            (print-visible-message (x mob) (y mob) (z mob) (level *world*)
                                   (format nil "~A falls and takes ~A damage. " (capitalize-name (prepend-article +article-the+ (visible-name mob))) cur-dmg) :observed-mob mob)))
        (when (check-dead mob)
          (make-dead mob :splatter t :msg t :msg-newline nil :killer nil :corpse t :aux-params ())
          (when (mob-effect-p mob +mob-effect-possessed+)
            (setf (cur-hp (get-mob-by-id (slave-mob-id mob))) 0)
            (setf (x (get-mob-by-id (slave-mob-id mob))) (x mob)
                  (y (get-mob-by-id (slave-mob-id mob))) (y mob)
                  (z (get-mob-by-id (slave-mob-id mob))) (z mob))
            (make-dead (get-mob-by-id (slave-mob-id mob)) :splatter nil :msg nil :msg-newline nil :corpse nil :aux-params ())))))
    
    ;; apply gravity to the mob, standing on your head, if any
    (when (and (get-terrain-* (level *world*) orig-x orig-y (1+ orig-z))
               (not (get-terrain-type-trait (get-terrain-* (level *world*) orig-x orig-y (1+ orig-z)) +terrain-trait-opaque-floor+))
               (get-mob-* (level *world*) orig-x orig-y (1+ orig-z))
               (not (eq mob (get-mob-* (level *world*) orig-x orig-y (1+ orig-z))))
               (and (mounted-by-mob-id mob)
                    (not (eq (get-mob-by-id (mounted-by-mob-id mob)) (get-mob-* (level *world*) orig-x orig-y (1+ orig-z))))))
      (format t "HERE~%")
      (set-mob-location (get-mob-* (level *world*) orig-x orig-y (1+ orig-z)) orig-x orig-y (1+ orig-z)))

    ;; check if the mob is constricting somebody or being constricted and if the effect should be broken
    (when (mob-effect-p mob +mob-effect-constriction-source+)
      (let ((effect (get-effect-by-id (mob-effect-p mob +mob-effect-constriction-source+))))
        (when (or (/= (first (first (param1 effect))) (x mob))
                  (/= (second (first (param1 effect))) (y mob))
                  (/= (third (first (param1 effect))) (z mob)))
          (rem-mob-effect mob +mob-effect-constriction-source+))))
    
    (when (mob-effect-p mob +mob-effect-constriction-target+)
      (let ((effect (get-effect-by-id (mob-effect-p mob +mob-effect-constriction-target+))))
        (when (or (/= (first (param1 effect)) (x mob))
                  (/= (second (param1 effect)) (y mob))
                  (/= (third (param1 effect)) (z mob)))
          (rem-mob-effect mob +mob-effect-constriction-target+))))
    )
  (logger (format nil "SET-MOB-LOCATION AFTER: ~A [~A] (~A ~A ~A)~%" (name mob) (id mob) (x mob) (y mob) (z mob))))

(defun move-mob (mob dir &key (push nil) (dir-z 0))
  (let ((dx 0)
        (dy 0)
        (sx (x mob))
        (sy (y mob))
        (along-dir)
        (opposite-dir)
        (not-along-dir)
        (near-opposite-dir)
        (to-the-left-dir)
        (to-the-right-dir)
        (c-dir))
    (declare (type fixnum dx dy))


    ;; if being ridden - restore the direction from the order being given by the rider
    (when (and (mounted-by-mob-id mob)
               (order-for-next-turn mob))
      (setf dir (first (order-for-next-turn mob)))
      (setf dir-z (second (order-for-next-turn mob))))
    
    (multiple-value-setq (dx dy) (x-y-dir dir))

    ;; if riding somebody, only give an order to your mount but do not move yourself
    (when (riding-mob-id mob)
      (logger (format nil "MOVE-MOB: ~A [~A] gives orders to mount ~A [~A] to move in the dir ~A~%" (name mob) (id mob) (name (get-mob-by-id (riding-mob-id mob))) (id (get-mob-by-id (riding-mob-id mob))) dir))

      ;; assign the order for the mount for its next turn
      (setf (order-for-next-turn (get-mob-by-id (riding-mob-id mob))) (list dir dir-z))
      
      ;; perform the attack in the chosen direction (otherwise it will be only the mount that attacks)
      (let ((check-result (check-move-on-level mob (+ (x mob) dx) (+ (y mob) dy) (+ (z mob) dir-z))))
        ;; right now multi-tile mobs can not ride other multitile mobs and I intend to leave it this way
        ;; this means that there will always be only one mob in the affected mob list
        (when (and check-result
                   (not (eq check-result t))
                   (eq (first check-result) :mobs)
                   (not (eq (get-mob-by-id (riding-mob-id mob))
                            (first (second check-result)))))
          (on-bump (first (second check-result)) mob)
          (return-from move-mob check-result))

        (when (or (eq check-result nil)
                  (and (eq (check-move-on-level (get-mob-by-id (riding-mob-id mob)) (+ (x mob) dx) (+ (y mob) dy) (+ (z mob) dir-z)) nil)
                       (= dir (x-y-into-dir (car (momentum-dir (get-mob-by-id (riding-mob-id mob)))) (cdr (momentum-dir (get-mob-by-id (riding-mob-id mob))))))))
          (logger (format nil "MOVE-MOB: ~A [~A] is unable to move to give order (CHECK = ~A, MOUNT DIR ~A)~%" (name mob) (id mob) check-result
                          (x-y-into-dir (car (momentum-dir (get-mob-by-id (riding-mob-id mob)))) (cdr (momentum-dir (get-mob-by-id (riding-mob-id mob)))))))
          (return-from move-mob nil)))

      ;; set motion
      (incf-mob-motion mob *mob-motion-order*)
      
      (make-act mob (truncate (* (cur-move-speed mob) (move-spd (get-mob-type-by-id (mob-type mob)))) 100))
      (return-from move-mob t))

    (setf c-dir (x-y-into-dir (car (momentum-dir mob)) (cdr (momentum-dir mob))))
    (multiple-value-setq (along-dir not-along-dir to-the-left-dir to-the-right-dir near-opposite-dir opposite-dir) (dir-neighbours c-dir))

    (when (mob-ability-p mob +mob-abil-momentum+)
      (setf push t))

    (logger (format nil "MOVE-MOB: ~A - spd ~A, c-dir ~A, dir ~A, dir-z ~A, ALONG-DIRS ~A, NOT-ALONG-DIRS ~A, OPPOSITE-DIRS ~A~%" (name mob) (momentum-spd mob) c-dir dir dir-z along-dir not-along-dir opposite-dir))
    (cond
      ;; NB: all this is necessary to introduce movement with momentum (for horses and the like)
      ;; (-1.-1) ( 0.-1) ( 1.-1)
      ;; (-1. 0) ( 0. 0) ( 1. 0)
      ;; (-1. 1) ( 0. 1) ( 1. 1)
      ;; if mob already moving in the direction ( 1. 1), then the chosen direction can be
      ;;   "opposite direction" which is (-1.-1)
      ;;   "along the direction" which is ( 1. 1), ( 0. 1) or ( 1. 0)
      ;;   "not along the direction" which is (-1. 1), (-1. 0), ( 1.-1) or ( 0.-1)
      ;;   "direction to the left" which is ( 1. -1) or ( 0.-1), note that mob's direction will be set to ( 1.-1) when the mob tries to change its direction abruptly
      ;;   "direction to the right" which is (-1. 1) or (-1. 0), note that mob's direction will be set to (-1. 1) when the mob tries to change its direction abruptly
      ;;   "near the opposite direction" which is (-1. 0) or ( 0.-1)
      ;; if speed is 0 or moving along the direction - increase spead and set the movement dir to chosen dir
      ((or (and (not (mob-ability-p mob +mob-abil-facing+))
                (zerop (momentum-spd mob))
                (/= dir 5))
           (and (/= dir 5)
                (find dir along-dir)))
       (progn
         (incf (momentum-spd mob))
         (setf (car (momentum-dir mob)) dx)
         (setf (cdr (momentum-dir mob)) dy)
         (logger (format nil "MOVE-MOB ALONG - SPD ~A DIR ~A DX ~A DY ~A~%" (momentum-spd mob) (momentum-dir mob) dx dy))))
      ;; if moving in the opposite direction - reduce speed 
      ((find dir opposite-dir)
       (progn
         (decf (momentum-spd mob))
         ;; if the mob is has facing, choose one of the directions neighbouring the opposite one, so that he turns around using this direction 
         (when (mob-ability-p mob +mob-abil-facing+)
           (multiple-value-setq (along-dir not-along-dir to-the-left-dir to-the-right-dir near-opposite-dir opposite-dir) (dir-neighbours dir))
           (if (zerop (random 2))
             (multiple-value-setq (dx dy) (x-y-dir (first near-opposite-dir)))
             (multiple-value-setq (dx dy) (x-y-dir (second near-opposite-dir))))
           (setf (car (momentum-dir mob)) dx)
           (setf (cdr (momentum-dir mob)) dy)
           (setf dx 0 dy 0))
         (logger (format nil "MOVE-MOB OPPOSITE - SPD ~A DIR ~A DX ~A DY ~A~%" (momentum-spd mob) (momentum-dir mob) dx dy))))
      ;; if moving not along the direction - reduce spead and change the direction
      ((find dir not-along-dir)
       (progn
         (decf (momentum-spd mob))
         ;; change direction either to the left or to the right depending on where the proposed direction lies
         (if (find dir to-the-left-dir)
           (multiple-value-setq (dx dy) (x-y-dir (first to-the-left-dir)))
           (multiple-value-setq (dx dy) (x-y-dir (first to-the-right-dir))))
         (setf (car (momentum-dir mob)) dx)
         (setf (cdr (momentum-dir mob)) dy)
         (when (mob-ability-p mob +mob-abil-facing+)
           (setf dx 0 dy 0))
         (logger (format nil "MOVE-MOB NOT ALONG - SPD ~A DIR ~A DX ~A DY ~A~%" (momentum-spd mob) (momentum-dir mob) dx dy))))
      )

    ;; normalize direction
    ;; for x axis
    (when (> (car (momentum-dir mob)) 1)
      (setf (car (momentum-dir mob)) 1))
    (when (< (car (momentum-dir mob)) -1)
      (setf (car (momentum-dir mob)) -1))
    ;; for y axis
    (when (> (cdr (momentum-dir mob)) 1)
      (setf (cdr (momentum-dir mob)) 1))
    (when (< (cdr (momentum-dir mob)) -1)
      (setf (cdr (momentum-dir mob)) -1))

    ;; limit max speed
    (when (and (mob-ability-p mob +mob-abil-momentum+)
               (> (momentum-spd mob) (mob-ability-p mob +mob-abil-momentum+)))
      (setf (momentum-spd mob) (mob-ability-p mob +mob-abil-momentum+)))
    (when (not (mob-ability-p mob +mob-abil-momentum+))
      (setf (momentum-spd mob) 0))
    (when (< (momentum-spd mob) 0)
      (setf (momentum-spd mob) 0))  

    (when (mob-ability-p mob +mob-abil-momentum+)
      (setf dx (car (momentum-dir mob)))
      (setf dy (cdr (momentum-dir mob))))

    (when (/= dir 5)
      (setf dir-z 0))
    
    (loop repeat (if (zerop (momentum-spd mob))
                   1
                   (momentum-spd mob))
          for move-result = nil
          for move-spd = (truncate (* (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-move-cost-factor+)
                                      (truncate (* (cur-move-speed mob) (move-spd (get-mob-type-by-id (mob-type mob)))) 100)))
          for x = (+ (x mob) dx)
          for y = (+ (y mob) dy)
          for z = (cond
                    ;; if the current cell is water and the cell along the direction is a wall - increase target z level, so that the mob can climb up
                    ((and (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-water+)
                          (get-terrain-type-trait (get-terrain-* (level *world*) x y (z mob)) +terrain-trait-blocks-move+))
                     (1+ (z mob)))
                    ;; if the current cell is slope up and the cell along the direction is a wall - increase the target z level, so that the mob can go up
                    ((and (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-slope-up+)
                          (get-terrain-type-trait (get-terrain-* (level *world*) x y (z mob)) +terrain-trait-blocks-move+))
                     (1+ (z mob)))
                    ;; if the target cell is slope down - decrease the target z level, so that the mob can go down
                    ((and (not (mob-effect-p mob +mob-effect-climbing-mode+))
                          (get-terrain-type-trait (get-terrain-* (level *world*) x y (z mob)) +terrain-trait-slope-down+))
                     (1- (z mob)))
                    ((and (< dir-z 0)
                          (= (z mob) 0))
                     0)
                    ((and (> dir-z 0)
                          (= (z mob) (1- (array-dimension (terrain (level *world*)) 2))))
                     0)
                    ;; otherwise the z level in unchanged
                    (t (+ (z mob) dir-z)))
          for apply-gravity = (if (or ;(not (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-water+))
                                      ;(not (get-terrain-type-trait (get-terrain-* (level *world*) x y z) +terrain-trait-water+))
                                   (and (not (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-water+))
                                        (not (get-terrain-type-trait (get-terrain-* (level *world*) x y z) +terrain-trait-water+)))
                                   (and (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-water+)
                                        (not (get-terrain-type-trait (get-terrain-* (level *world*) x y z) +terrain-trait-water+)))
                                   (and (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-water+)
                                        (get-terrain-type-trait (get-terrain-* (level *world*) x y z) +terrain-trait-water+)
                                        (= z (z mob))
                                        (= dx 0)
                                        (= dy 0)))
                                t
                                nil)
          for check-result = (if (check-move-along-z (x mob) (y mob) (z mob) x y z)
                               (check-move-on-level mob x y z)
                               nil)
          
          do
             (logger (format nil "MOVE-MOB: CHECK-MOVE ~A, XYZ = (~A ~A ~A)~%" check-result x y z))
             (cond
               ;; all clear - move freely
               ((eq check-result t)

                (when (and (= z (z mob))
                           (= x (x mob))
                           (= y (y mob)))
                  (setf move-spd (truncate (* (cur-move-speed mob) (move-spd (get-mob-type-by-id (mob-type mob)))) 100)))
                ;(format t "APPLY-GRAVITY ~A~%" apply-gravity)
                (set-mob-location mob x y z :apply-gravity apply-gravity)

                (when (not (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-water+))
                  (setf dir-z 0))
                
                (setf move-result t)
                
                )
               ;; bumped into an obstacle or the map border
               ((or (eq check-result nil) (eq (first check-result) :obstacles))

                 (when (mob-ability-p mob +mob-abil-momentum+)
                  (setf (momentum-spd mob) 0)
                  (setf (momentum-dir mob) (cons 0 0)))
                (setf (order-for-next-turn mob) (list 5 0))

                ;; if the obstacle is bumpable - bump & exit
                (when (and (eq (first check-result) :obstacles)
                           (get-terrain-on-bump (get-terrain-* (level *world*) x y z))
                           (funcall (get-terrain-on-bump (get-terrain-* (level *world*) x y z)) mob x y z))
                  (setf move-result :ability-invoked)
                  (loop-finish))
                
                ;; a precaution so that horses finish their turn when they made a move and bumped into an obstacle
                ;; while not finishing their turn if they try to move into an obstacle standing next to it
                (when (or (/= sx (x mob))
                          (/= sy (y mob))
                          (and (mob-ability-p mob +mob-abil-facing+)
                               (/= c-dir (x-y-into-dir dx dy)))
                          )
                  (make-act mob move-spd))
                (setf move-result nil)
                (loop-finish)
                )
               ;; bumped into a mob
               ((eq (first check-result) :mobs) 
                (logger (format nil "MOVE-MOB: ~A [~A] bumped into mobs (~A)~%" (name mob) (id mob) (loop named nil
                                                                                                          with str = (create-string)
                                                                                                          for tmob in (second check-result)
                                                                                                          do
                                                                                                             (format str "~A [~A], " (name tmob) (id tmob))
                                                                                                          finally
                                                                                                             (return-from nil str))))

                (loop with cur-ap = (cur-ap mob) 
                      for target-mob in (second check-result) do
                        ;; if the mount bumps into its rider - do nothing
                        (if (and (mounted-by-mob-id mob)
                                 (eq target-mob (get-mob-by-id (mounted-by-mob-id mob))))
                          (progn 
                            (setf move-result t))
                          (progn
                            (when (and push
                                       (not (mob-ability-p target-mob +mob-abil-immovable+)))
                              ;; check if you can push the mob farther
                              (let* ((nx (+ (car (momentum-dir mob)) (x target-mob)))
                                     (ny (+ (cdr (momentum-dir mob)) (y target-mob)))
                                     (check-result-n (check-move-on-level target-mob nx ny z)))
                                (when (eq check-result-n t)
                                  
                                  (incf-mob-motion mob *mob-motion-move*)
                                  (incf-mob-motion target-mob *mob-motion-move*)
                                  (set-mob-location target-mob nx ny z :apply-gravity (if
                                                                                          (or (not (get-terrain-type-trait (get-terrain-* (level *world*) (x target-mob) (y target-mob) (z target-mob)) +terrain-trait-water+))
                                                                                              (and (get-terrain-type-trait (get-terrain-* (level *world*) (x target-mob) (y target-mob) (z target-mob)) +terrain-trait-water+)
                                                                                                   (= z (+ (z target-mob) dir-z))
                                                                                                   (= dx 0)
                                                                                                   (= dy 0)))
                                                                                        t
                                                                                        nil))
                                  (set-mob-location mob x y z :apply-gravity apply-gravity)
                                  (when (or (check-mob-visible mob :observer *player*)
                                            (check-mob-visible target-mob :observer *player*))
                                    (print-visible-message (x mob) (y mob) (z mob) (level *world*) 
                                                           (format nil "~A pushes ~A. " (capitalize-name (prepend-article +article-the+ (visible-name mob))) (prepend-article +article-the+ (visible-name target-mob))))))
                                ))
                            (on-bump target-mob mob)))
                      finally
                         (when (> (map-size mob) 1)
                           (setf (cur-ap mob) cur-ap)
                           (make-act mob (get-melee-weapon-speed mob))))

                (when (eq move-result t)
                  (loop-finish))
                                
                
                (when (mob-ability-p mob +mob-abil-momentum+)
                  (setf (momentum-spd mob) 0)
                  (setf (momentum-dir mob) (cons 0 0)))
                (setf move-result check-result)
                (loop-finish))
               )
          finally
             (setf (order-for-next-turn mob) nil)
             (cond
               ((mob-ability-p mob +mob-abil-momentum+) (when (zerop (momentum-spd mob))
                                                          (setf (momentum-dir mob) (cons 0 0))))
               ((mob-ability-p mob +mob-abil-facing+) nil)
               (t (setf (momentum-dir mob) (cons 0 0))))
             
             (when (eq move-result t)
               (make-act mob move-spd))
             
             (return-from move-mob move-result))
    )
  nil)

(defun make-act (mob speed)
  (logger (format nil "MAKE-ACT: ~A SPD ~A~%" (name mob) speed))
  (when (zerop speed) (return-from make-act nil))
  (decf (cur-ap mob) (truncate (* speed (cur-speed mob)) 100))
  (setf (made-turn mob) t)
  (when (eq mob *player*)
    (incf (player-game-time *world*) (truncate (* speed +normal-ap+) (max-ap mob)))))

(defun stumble-upon-mob (actor target)
  (logger (format nil "STUMBLE-UPON-MOB: ~A [~A] stumbled upon ~A [~A]~%" (name actor) (id actor) (name target) (id target)))

  
  
  (set-mob-effect actor :effect-type-id +mob-effect-alertness+ :actor-id (id actor) :cd 5)
  (incf-mob-motion target 100)
  (pushnew (id actor) (visible-mobs target))
  (when (riding-mob-id target)
    (pushnew (id actor) (visible-mobs (get-mob-by-id (riding-mob-id target)))))
  (when (mounted-by-mob-id target)
    (pushnew (id actor) (visible-mobs (get-mob-by-id (mounted-by-mob-id target)))))
  (pushnew (id target) (visible-mobs actor))
  (when (riding-mob-id actor)
    (pushnew (id target) (visible-mobs (get-mob-by-id (riding-mob-id actor)))))
  (when (mounted-by-mob-id actor)
    (pushnew (id target) (visible-mobs (get-mob-by-id (mounted-by-mob-id actor)))))
  
  (when (or (eq *player* actor)
            (eq *player* target)
            (check-mob-visible actor :observer *player* :complete-check t)
            (check-mob-visible target :observer *player* :complete-check t))
    (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                           (format nil "~A stumbles upon ~A! " (capitalize-name (prepend-article +article-the+ (visible-name actor))) (prepend-article +article-the+ (visible-name target)))))
  )

(defmethod on-bump ((target mob) (actor mob))
  (if (eql target actor)
    (progn
      (make-act actor (truncate (* (cur-move-speed actor) (move-spd (get-mob-type-by-id (mob-type actor)))) 100)))
      (progn 
        (logger (format nil "ON-BUMP: ~A [~A] bumped into ~A [~A]~%" (name actor) (id actor) (name target) (id target)))
        
        ;; if they are of the same faction and do not like infighting - do nothing
        (when (or (and (= (faction actor) (faction target))
                       (not (mob-ability-p actor +mob-abil-loves-infighting+)))
                  (and (order actor)
                       (= (first (order actor)) +mob-order-follow+)
                       (= (second (order actor)) (id target)))
                  (and (order actor)
                       (order target)
                       (= (first (order actor)) +mob-order-follow+)
                       (= (first (order target)) +mob-order-follow+)
                       (= (second (order actor)) (second (order target)))))
          (logger (format nil "ON-BUMP: ~A [~A] and ~A [~A] are of the same faction and would not attack each other~%" (name actor) (id actor) (name target) (id target)))
          (make-act actor (truncate (* (cur-move-speed actor) (move-spd (get-mob-type-by-id (mob-type actor)))) 100))
          (return-from on-bump t))

        (when (not (check-mob-visible target :observer actor))
          (stumble-upon-mob actor target))
        
        ;; if the target is mounted, 50% chance that the actor will bump target's mount
        (when (riding-mob-id target)
          (when (zerop (random 2))
            (setf target (get-mob-by-id (riding-mob-id target)))))
        
        (let ((abil-list nil))
          ;; collect all passive non-final on-touch abilities
          (setf abil-list (loop for abil-type-id in (get-mob-all-abilities actor)
                                when (and (abil-passive-p abil-type-id)
                                          (abil-on-touch-p abil-type-id)
                                          (not (abil-final-p abil-type-id)))
                                  collect abil-type-id))
          ;; invoke all applicable abilities
          (loop for abil-type-id in abil-list
                when (can-invoke-ability actor target abil-type-id)
                  do
                     (mob-invoke-ability actor target abil-type-id))
          )
        
        (let ((abil-list nil))
          ;; collect all passive final on-touch abilities
          (setf abil-list (loop for abil-type-id in (get-mob-all-abilities actor)
                                when (and (abil-passive-p abil-type-id)
                                          (abil-on-touch-p abil-type-id)
                                          (abil-final-p abil-type-id))
                                  collect abil-type-id))
          
          ;; invoke first applicable ability 
          (loop for abil-type-id in abil-list
                when (can-invoke-ability actor target abil-type-id)
                  do
                     (mob-invoke-ability actor target abil-type-id)
                     (return-from on-bump t))
          )
        
        ;; if no abilities could be applied - melee target
        (melee-target actor target)
        ;; if the target is killed without purging - the slave mob also dies
        (when (and (check-dead target)
                   (mob-effect-p target +mob-effect-possessed+))
          (setf (cur-hp (get-mob-by-id (slave-mob-id target))) 0)
          (setf (x (get-mob-by-id (slave-mob-id target))) (x target)
                (y (get-mob-by-id (slave-mob-id target))) (y target)
                (z (get-mob-by-id (slave-mob-id target))) (z target))
          (make-dead (get-mob-by-id (slave-mob-id target)) :splatter nil :msg nil :msg-newline nil :corpse nil :aux-params nil))
        )))
                     
(defun mob-depossess-target (actor)
  (logger (format nil "MOB-DEPOSSESS-TARGET: Master ~A [~A], slave [~A]~%" (name actor) (id actor) (slave-mob-id actor)))
  (let ((target (get-mob-by-id (slave-mob-id actor))))
    (logger (format nil "MOB-DEPOSSESS-TARGET: ~A [~A] releases its possession of ~A [~A]~%" (name actor) (id actor) (name target) (id target)))
    (setf (x target) (x actor) (y target) (y actor) (z target) (z actor))
    (add-mob-to-level-list (level *world*) target)
    
    (setf (master-mob-id target) nil)
    (setf (slave-mob-id actor) nil)
    (setf (face-mob-type-id actor) (mob-type actor))
    (rem-mob-effect actor +mob-effect-possessed+)
    (rem-mob-effect target +mob-effect-possessed+)
    (rem-mob-effect target +mob-effect-reveal-true-form+)

    ;; if the master is riding something - put slave as the rider
    (when (riding-mob-id actor)
      (setf (riding-mob-id target) (riding-mob-id actor))
      (setf (mounted-by-mob-id (get-mob-by-id (riding-mob-id target))) (id target)))
    
    (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                           (format nil "~A releases its possession of ~A. " (capitalize-name (prepend-article +article-the+ (name actor))) (prepend-article +article-the+ (name target))))
  
    ))

(defun mob-burn-blessing (actor target)
  
  (inflict-damage target :min-dmg 1 :max-dmg 2 :dmg-type +weapon-dmg-fire+
                         :att-spd nil :weapon-aux () :acc 100 :add-blood t :no-dodge t :no-hit-message t :no-check-dead t
                         :actor actor
                         :specific-hit-string-func #'(lambda (cur-dmg)
                                                       (format nil "~A is scorched by ~A for ~A damage. " (capitalize-name (prepend-article +article-the+ (name target))) (prepend-article +article-the+ (visible-name actor)) cur-dmg)))
  (when (zerop (random 4))
    (generate-sound target (x target) (y target) (z target) 80 #'(lambda (str)
                                                                   (format nil "You hear gasps~A." str))))
  (when (check-dead target)
    (when (mob-effect-p target +mob-effect-possessed+)
      (mob-depossess-target target))
    
    (make-dead target :splatter t :msg t :msg-newline nil :killer actor :corpse t :aux-params (list :is-fire))
    )
  )

(defun mob-can-shoot (actor)
  (unless (is-weapon-ranged actor)
    (return-from mob-can-shoot nil))

  (if (not (zerop (get-ranged-weapon-charges actor)))
    t
    nil))

(defun mob-reload-ranged-weapon (actor)
  (unless (is-weapon-ranged actor)
    (return-from mob-reload-ranged-weapon nil))

  (logger (format nil "MOB-RELOAD: ~A [~A] reloads his ~A~%" (name actor) (id actor) (get-weapon-name actor)))

  ;; set motion
  (incf-mob-motion actor *mob-motion-reload*)

  ;; generate sound
  (generate-sound actor (x actor) (y actor) (z actor) *mob-sound-reload* #'(lambda (str)
                                                                             (format nil "You hear some clanking sounds~A. " str)))
  
  (set-ranged-weapon-charges actor (get-ranged-weapon-max-charges actor))
  (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                         (format nil "~A reloads his ~(~A~). " (capitalize-name (prepend-article +article-the+ (visible-name actor))) (get-weapon-name actor)))

  (make-act actor +normal-ap+))

(defun mob-shoot-target (actor target)
  (let ((cur-dmg 0) (bullets-left) (affected-targets nil) (completely-missed t))
    (unless (is-weapon-ranged actor)
      (return-from mob-shoot-target nil))

    ;; set motion
    (incf-mob-motion actor *mob-motion-shoot*)

     ;; generate sound
    (generate-sound actor (x actor) (y actor) (z actor) *mob-sound-shoot* #'(lambda (str)
                                                                               (format nil "You hear shooting~A. " str)))
    
     ;; reduce the number of bullets in the magazine
    (if (> (get-ranged-weapon-charges actor) (get-ranged-weapon-rof actor))
      (progn
        (setf bullets-left (get-ranged-weapon-rof actor))
        (set-ranged-weapon-charges actor (- (get-ranged-weapon-charges actor) (get-ranged-weapon-rof actor))))
      (progn
        (setf bullets-left (get-ranged-weapon-charges actor))
        (set-ranged-weapon-charges actor 0)))

    (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                           (format nil "~A shoots ~A. " (capitalize-name (prepend-article +article-the+ (visible-name actor))) (prepend-article +article-the+ (visible-name target))))
    
    (loop repeat bullets-left
          with rx
          with ry
          with target1
          with tx
          with ty
          with tz
          do
             (setf rx 0 ry 0)
             ;; disperse ammo depending on the distance to the target
             (let ((dist (get-distance (x actor) (y actor) (x target) (y target))))
               (when (and (>= dist 2)
                          (< (- (r-acc actor) (* dist *acc-loss-per-tile*)) (random 100)))
                 (setf rx (- (random (+ 3 (* 2 (truncate dist (r-acc actor))))) 
                             (+ 1 (truncate dist (r-acc actor)))))
                 (setf ry (- (random (+ 3 (* 2 (truncate dist (r-acc actor))))) 
                             (+ 1 (truncate dist (r-acc actor)))))))
      
             ;; trace a line to the target so if we encounter an obstacle along the path we hit it
             (line-of-sight (x actor) (y actor) (z actor) (+ (x target) rx) (+ (y target) ry) (z target)
                            #'(lambda (dx dy dz prev-cell)
                                (declare (type fixnum dx dy dz))
                                (let ((exit-result t))
                                  (block nil
                                    (setf tx dx ty dy tz dz)

                                    (unless (check-LOS-propagate dx dy dz prev-cell :check-projectile t)
                                      (setf exit-result 'exit)
                                      (return))
                                    )
                                  exit-result)))
             ;; place a fire dot if the dest point is visible
             (place-animation tx ty tz +anim-type-fire-dot+ :params ())
             
             (setf target1 (get-mob-* (level *world*) tx ty tz))

             ;; if the target is mounted, 50% chance that the actor will hit target's mount
             (when (and target1
                        (riding-mob-id target1))
               (when (zerop (random 2))
                 (setf target1 (get-mob-by-id (riding-mob-id target1)))))
                         
             (when target1
               (setf completely-missed nil)

               (setf cur-dmg (inflict-damage target :min-dmg (get-ranged-weapon-dmg-min actor) :max-dmg (get-ranged-weapon-dmg-max actor) :dmg-type (get-ranged-weapon-dmg-type actor)
                                                    :att-spd nil :weapon-aux (get-ranged-weapon-aux actor) :acc 100 :add-blood t :no-dodge t :no-hit-message t :no-check-dead t
                                                    :actor actor))
                           
               (if (find target1 affected-targets :key #'(lambda (n) (car n)))
                 (incf (cdr (find target1 affected-targets :key #'(lambda (n) (car n)))) cur-dmg)
                 (push (cons target1 cur-dmg) affected-targets))
               
               )
          )
    
    (loop for (a-target . dmg) in affected-targets do
      (if (zerop dmg)
          (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                 (format nil "~A is not hurt. " (capitalize-name (prepend-article +article-the+ (visible-name a-target)))))
          (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                 (format nil "~A is hit for ~A damage. " (capitalize-name (prepend-article +article-the+ (visible-name a-target))) dmg)))
      (when (check-dead a-target)
        (make-dead a-target :splatter t :msg t :msg-newline nil :killer actor :corpse t :aux-params (get-ranged-weapon-aux actor))
          
        (when (mob-effect-p a-target +mob-effect-possessed+)
          (setf (cur-hp (get-mob-by-id (slave-mob-id a-target))) 0)
          (setf (x (get-mob-by-id (slave-mob-id a-target))) (x a-target)
                (y (get-mob-by-id (slave-mob-id a-target))) (y a-target)
                (z (get-mob-by-id (slave-mob-id a-target))) (z a-target))
          (make-dead (get-mob-by-id (slave-mob-id a-target)) :splatter nil :msg nil :msg-newline nil :corpse nil :aux-params ()))
        ))
    
    (when completely-missed
      (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                             (format nil "~A misses. " (capitalize-name (prepend-article +article-the+ (visible-name actor)))))
      )
    (make-act actor (get-ranged-weapon-speed actor))
    ))

(defun mob-invoke-ability (actor target ability-type-id)
  (when (can-invoke-ability actor target ability-type-id)
    (let ((ability-type (get-ability-type-by-id ability-type-id)))
      (when (and (removes-disguise ability-type)
                 (mob-effect-p actor +mob-effect-disguised+))
        (rem-mob-effect actor +mob-effect-disguised+))
      (funcall (on-invoke ability-type) ability-type actor target)
      (set-abil-cur-cd actor ability-type-id (abil-max-cd-p ability-type-id))
      (incf-mob-motion actor (motion ability-type))
      (make-act actor (spd ability-type)))))

(defun mob-use-item (actor item)
  (when (on-use item)
    (when (funcall (on-use item) actor item)
      (setf (inv actor) (remove-from-inv item (inv actor) :qty 1))
      (remove-item-from-world item))
    (incf-mob-motion actor *mob-motion-use-item*)
    (make-act actor (truncate +normal-ap+ 2))))

(defun inflict-damage (target &key (min-dmg 0) (max-dmg 0) (dmg-type +weapon-dmg-iron+) (att-spd nil) (weapon-aux nil) (actor nil) (acc 100) (no-dodge nil) (add-blood t) (no-hit-message nil) (no-check-dead nil)
                                   (specific-hit-string-func nil) (specific-no-dmg-string-func nil))
  ;; specific-hit-string-func is #'(lambda (cur-dmg) (return string))
  ;; specific-no-dmg-string-func is #'(lambda () (return string))
  (logger (format nil "INFLICT-DAMAGE: target = ~A [~A]~%" (name target) (id target)))

  ;; target under protection of divine shield - consume the shield and quit
  (when (mob-effect-p target +mob-effect-divine-shield+)
    (if actor
      (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                             (format nil "~A attacks ~A, but can not harm ~A. "
                                     (capitalize-name (prepend-article +article-the+ (visible-name actor)))
                                     (prepend-article +article-the+ (visible-name target))
                                     (prepend-article +article-the+ (visible-name target))))
      (print-visible-message (x target) (y target) (z target) (level *world*) 
                             (format nil "~A is not harmed. " (capitalize-name (prepend-article +article-the+ (visible-name target))))))
    (rem-mob-effect target +mob-effect-divine-shield+)
    (when (and actor att-spd) (make-act actor att-spd))
    (return-from inflict-damage nil))
  
  ;; if the target has keen senses - destroy the illusions
  (when (mob-ability-p target +mob-abil-keen-senses+)
    (when (and actor
               (mob-effect-p actor +mob-effect-divine-concealed+))
      (rem-mob-effect actor +mob-effect-divine-concealed+)
      (when (or (check-mob-visible actor :observer *player*)
                (check-mob-visible target :observer *player*))
        (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                               (format nil "~A reveals the true form of ~A. " (capitalize-name (prepend-article +article-the+ (visible-name target))) (prepend-article +article-the+ (get-qualified-name actor))))))
    (when (and actor
               (mob-effect-p actor +mob-effect-possessed+))
      (unless (mob-effect-p actor +mob-effect-reveal-true-form+)
        (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                               (format nil "~A reveals the true form of ~A. " (capitalize-name (prepend-article +article-the+ (visible-name target))) (prepend-article +article-the+ (get-qualified-name actor)))))
      (set-mob-effect actor :effect-type-id +mob-effect-reveal-true-form+ :actor-id (id actor) :cd 5)))

  ;; if the attacker is disguised - remove the disguise
  (when (and actor
             (mob-effect-p actor +mob-effect-disguised+))
    (rem-mob-effect actor +mob-effect-disguised+))

  (multiple-value-bind (dx dy) (x-y-dir (1+ (random 9)))
    (let* ((cur-dmg) (dodge-chance) 
	   (x (+ dx (x target))) (y (+ dy (y target)))
           (dodge-target (cur-dodge target))
	   (check-result (check-move-on-level target x y (z target))))
      ;; check if attacker has hit the target
      (if (> acc (random 100))
        (progn
          ;; attacker hit
          ;; check if the target dodged
          (setf dodge-chance (random 100))

          (if (and (> dodge-target dodge-chance) 
                   (eq check-result t)
                   (not no-dodge))
            ;; target dodged
            (progn

              (cond
                ((and actor
                      (not no-hit-message)
                      (get-single-memo-visibility (get-memo-* (level *world*) (x actor) (y actor) (z actor)))
                      (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target)))
                      (check-mob-visible actor :observer *player*)
                      (check-mob-visible target :observer *player*))
                 (progn
                   (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                          (format nil "~A attacks ~A, but ~A evades the attack. "
                                                  (capitalize-name (prepend-article +article-the+ (visible-name actor)))
                                                  (prepend-article +article-the+ (visible-name target))
                                                  (prepend-article +article-the+ (visible-name target))))))
                ((and actor
                      (not no-hit-message)
                      (get-single-memo-visibility (get-memo-* (level *world*) (x actor) (y actor) (z actor)))
                      (check-mob-visible actor :observer *player*))
                 (progn
                   (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                          (format nil "~A attacks somebody, but it evades the attack. " (capitalize-name (prepend-article +article-the+ (visible-name actor)))))))
                ((and (not no-hit-message)
                      (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target)))
                      (check-mob-visible target :observer *player*))
                 (progn
                   (print-visible-message (x target) (y target) (z target) (level *world*) 
                                          (format nil "Somebody attacks ~A, but ~A evades the attack. "
                                                  (prepend-article +article-the+ (visible-name target))
                                                  (prepend-article +article-the+ (visible-name target)))))))
              
              (set-mob-location target x y (z target))

              ;; reduce the momentum to zero
              (setf (momentum-dir target) (cons 0 0))
              (setf (momentum-spd target) 0)

              )
            ;; target did not dodge
            (progn
              ;; apply damage
              (setf cur-dmg (+ (random (- (1+ max-dmg) min-dmg)) 
                               min-dmg))
              
              (when (and actor
                         (= (faction actor) (faction target)))
                (setf cur-dmg min-dmg))

              ;; if the attacker is under pain link effect and the target is the caster of pain link then amplify the damage by 30% 
              (when (and actor
                         (mob-effect-p actor +mob-effect-pain-link-target+)
                         (= (id target) (actor-id (get-effect-by-id (mob-effect-p actor +mob-effect-pain-link-target+)))))
                (setf cur-dmg (truncate (* cur-dmg 1.3))))

              ;; if the attacker is under pain link effect and the target is NOT the caster of pain link then decrease the damage by 30% 
              (when (and actor
                         (mob-effect-p actor +mob-effect-pain-link-target+)
                         (/= (id target) (actor-id (get-effect-by-id (mob-effect-p actor +mob-effect-pain-link-target+)))))
                (setf cur-dmg (truncate (* cur-dmg 0.7))))

              ;; reduce damage by the amount of risistance to this damage type
              ;; first reduce the damage directly
              ;; then - by percent
              (when (get-armor-resist target dmg-type)
                (decf cur-dmg (get-armor-d-resist target dmg-type))
                (setf cur-dmg (truncate (* cur-dmg (- 100 (get-armor-%-resist target dmg-type))) 100)))
              (when (< cur-dmg 0) (setf cur-dmg 0))

              ;; check for soul reinforcement on target
              (when (and (mob-effect-p target +mob-effect-soul-reinforcement+)
                         (<= (- (cur-hp target) cur-dmg) 0))
                (setf cur-dmg (1- (cur-hp target)))
                (rem-mob-effect target +mob-effect-soul-reinforcement+)
                (print-visible-message (x target) (y target) (z target) (level *world*) 
                                       (format nil "Reinforced soul of ~A prevents a fatal blow. " (prepend-article +article-the+ (visible-name target)))))
              
              (decf (cur-hp target) cur-dmg)
              ;; place a blood spattering
              (when (and add-blood
                         (not (zerop cur-dmg)))
                (let ((dir (1+ (random 9))))
                  (multiple-value-bind (dx dy) (x-y-dir dir) 				
                    (when (> 50 (random 100))
                      (add-feature-to-level-list (level *world*) 
                                                 (make-instance 'feature :feature-type +feature-blood-fresh+ :x (+ (x target) dx) :y (+ (y target) dy) :z (z target)))))))
              (if (zerop cur-dmg)
                (progn
                  (cond
                    ((and actor
                          (not no-hit-message)
                          (not specific-no-dmg-string-func)
                          (get-single-memo-visibility (get-memo-* (level *world*) (x actor) (y actor) (z actor)))
                          (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target))))
                     (progn
                       (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                              (format nil "~A hits ~A, but ~A is not hurt. "
                                                      (capitalize-name (prepend-article +article-the+ (visible-name actor)))
                                                      (prepend-article +article-the+ (visible-name target))
                                                      (prepend-article +article-the+ (visible-name target))))))
                    ((and actor
                          (not no-hit-message)
                          (not specific-no-dmg-string-func)
                          (get-single-memo-visibility (get-memo-* (level *world*) (x actor) (y actor) (z actor))))
                     (progn
                       (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                              (format nil "~A hits somebody, but it is not hurt. " (capitalize-name (prepend-article +article-the+ (visible-name actor)))))))
                    ((and actor
                          (not no-hit-message)
                          (not specific-no-dmg-string-func)
                          (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target))))
                     (progn
                       (print-visible-message (x target) (y target) (z target) (level *world*) 
                                              (format nil "Somebody hits ~A, but ~A is not hurt. " (prepend-article +article-the+ (visible-name target)) (prepend-article +article-the+ (visible-name target))))))
                    ((and (not actor)
                          (not no-hit-message)
                          (not specific-no-dmg-string-func)
                          (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target))))
                     (progn
                       (print-visible-message (x target) (y target) (z target) (level *world*) 
                                              (format nil "~A is not hurt. " (capitalize-name (prepend-article +article-the+ (visible-name target)))))))
                    ((and specific-no-dmg-string-func
                          (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target))))
                     (progn
                       (print-visible-message (x target) (y target) (z target) (level *world*) 
                                              (funcall specific-no-dmg-string-func))))))
                (progn
                  (cond
                    ((and actor
                          (not no-hit-message)
                          (get-single-memo-visibility (get-memo-* (level *world*) (x actor) (y actor) (z actor)))
                          (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target))))
                     (progn
                       (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                              (format nil "~A hits ~A for ~A damage. " (capitalize-name (prepend-article +article-the+ (visible-name actor))) (prepend-article +article-the+ (visible-name target)) cur-dmg))))
                    ((and actor
                          (not no-hit-message)
                          (get-single-memo-visibility (get-memo-* (level *world*) (x actor) (y actor) (z actor))))
                     (progn
                       (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                              (format nil "~A hits somebody for ~A damage. " (capitalize-name (prepend-article +article-the+ (visible-name actor))) cur-dmg))))
                    ((and actor
                          (not no-hit-message)
                          (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target))))
                     (progn
                       (print-visible-message (x target) (y target) (z target) (level *world*) 
                                              (format nil "Somebody hits ~A for ~A damage. " (prepend-article +article-the+ (visible-name target)) cur-dmg))))
                    ((and (not actor)
                          (not no-hit-message)
                          (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target))))
                     (progn
                       (print-visible-message (x target) (y target) (z target) (level *world*) 
                                              (format nil "~A takes ~A damage. " (capitalize-name (prepend-article +article-the+ (visible-name target))) cur-dmg))))
                    ((and specific-hit-string-func
                          (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target))))
                     (progn
                       (print-visible-message (x target) (y target) (z target) (level *world*) 
                                              (funcall specific-hit-string-func cur-dmg))))))
                )
              ;; if the attacker can constrict - constrict around the target
              (when (and actor
                         weapon-aux
                         (find :constricts weapon-aux))
                (set-mob-effect target :effect-type-id +mob-effect-constriction-target+ :actor-id (id actor) :param1 (list (x target) (y target) (z target)))
                (if (mob-effect-p actor +mob-effect-constriction-source+)
                  (progn
                    (let ((effect (get-effect-by-id (mob-effect-p actor +mob-effect-constriction-source+))))
                      (setf (second (param1 effect)) (append (second (param1 effect)) (list (id target))))))
                  (progn
                    (set-mob-effect actor :effect-type-id +mob-effect-constriction-source+ :actor-id (id actor) :param1 (list (list (x actor) (y actor) (z actor))
                                                                                                                              (list (id target))))))
                (print-visible-message (x target) (y target) (z target) (level *world*) 
                                       (format nil "~A grabs ~A. " (capitalize-name (prepend-article +article-the+ (visible-name actor))) (prepend-article +article-the+ (visible-name target)))))
              )))
        (progn
          ;; attacker missed
          (cond
            ((and actor
                  (not no-hit-message)
                  (get-single-memo-visibility (get-memo-* (level *world*) (x actor) (y actor) (z actor)))
                  (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target))))
             (progn
               (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                      (format nil "~A misses ~A. " (capitalize-name (prepend-article +article-the+ (visible-name actor))) (prepend-article +article-the+ (visible-name target))))))
            ((and actor
                  (not no-hit-message)
                  (get-single-memo-visibility (get-memo-* (level *world*) (x actor) (y actor) (z actor))))
             (progn
               (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                      (format nil "~A misses somebody. " (capitalize-name (prepend-article +article-the+ (visible-name actor)))))))
            ((and actor
                  (not no-hit-message)
                  (get-single-memo-visibility (get-memo-* (level *world*) (x target) (y target) (z target))))
             (progn
               (print-visible-message (x target) (y target) (z target) (level *world*) 
                                      (format nil "Somebody misses ~A. " (prepend-article +article-the+ (visible-name target)))))))
          
          ))

      (when (and (not no-check-dead)
                 (check-dead target))
        (make-dead target :splatter t :msg t :msg-newline nil :killer actor :corpse t :aux-params weapon-aux)
        (when (mob-effect-p target +mob-effect-possessed+)
          (setf (cur-hp (get-mob-by-id (slave-mob-id target))) 0)
          (setf (x (get-mob-by-id (slave-mob-id target))) (x target)
                (y (get-mob-by-id (slave-mob-id target))) (y target)
                (z (get-mob-by-id (slave-mob-id target))) (z target))
          (make-dead (get-mob-by-id (slave-mob-id target)) :splatter nil :msg nil :msg-newline nil :corpse nil :aux-params ()))                                                                                             
        )
  
      (when (and actor att-spd) (make-act actor att-spd))

      cur-dmg))
  )

(defun melee-target (attacker target)
  (logger (format nil "MELEE-TARGET: ~A attacks ~A~%" (name attacker) (name target)))
  ;; no weapons - no attack
  (unless (weapon attacker)
    (make-act attacker +normal-ap+)
    (return-from melee-target nil))

  ;; set motion
  (incf-mob-motion attacker *mob-motion-melee*)
  
  ;; generate sound
  (generate-sound attacker (x attacker) (y attacker) (z attacker) *mob-sound-melee* #'(lambda (str)
                                                                                        (format nil "You hear sounds of fighting~A. " str)))

  (inflict-damage target :min-dmg (get-melee-weapon-dmg-min attacker) :max-dmg (get-melee-weapon-dmg-max attacker) :dmg-type (get-melee-weapon-dmg-type attacker)
                         :att-spd (get-melee-weapon-speed attacker) :weapon-aux (get-melee-weapon-aux-simple (weapon attacker)) :acc (m-acc attacker) :add-blood t 
                         :actor attacker)
  )

(defun check-dead (mob)
  (when (<= (cur-hp mob) 0)
    (return-from check-dead t))
  nil)

(defun make-dead (mob &key (splatter t) (msg nil) (msg-newline nil) (killer nil) (corpse t) (aux-params ()))
  (logger (format nil "MAKE-DEAD: ~A [~A] (~A ~A ~A)~%" (name mob) (id mob) (x mob) (y mob) (z mob)))
  (let ((dead-msg-str (format nil "~A dies. " (capitalize-name (prepend-article +article-the+ (visible-name mob))))))
    
    (when (dead= mob)
      (return-from make-dead nil))

    (loop for merged-id in (merged-id-list mob)
          for merged-mob = (get-mob-by-id merged-id)
          do
             (setf (cur-hp merged-mob) 0)
             (make-dead merged-mob :splatter nil :msg nil :corpse nil))
    
    (when (and (eq mob *player*)
               killer)
      (setf (killed-by *player*) (multiple-value-list (get-qualified-name killer))))

    (when (and killer
               (eq killer *player*))
      (incf (cur-score *player*) (* 10 (strength mob)))
      (when (and (mob-ability-p *player* +mob-abil-demon+)
                 (= (strength mob) 0))
        (incf (cur-score *player*) 5)))
    
    (when (mob-ability-p mob +mob-abil-human+)
      (decf (total-humans *world*)))
    (when (mob-ability-p mob +mob-abil-demon+)
      (decf (total-demons *world*)))
    (when (mob-ability-p mob +mob-abil-undead+)
      (decf (total-undead *world*)))
    (when (and (mob-ability-p mob +mob-abil-angel+)
               (not (mob-ability-p mob +mob-abil-animal+)))
      (decf (total-angels *world*)))
    
    ;; set stat-gold before dropping inventory
    (setf (stat-gold mob) (get-overall-value (inv mob)))

    ;; remove all effects on death
    (loop for effect-id being the hash-value in (effects mob)
          for effect = (get-effect-by-id effect-id)
          do
             (when (not (= (effect-type effect) +mob-effect-climbing-mode+))
               (rem-mob-effect mob (effect-type effect))))
    
    ;; place the inventory on the ground
    (loop for item-id in (inv mob)
          for item = (get-item-by-id item-id)
          do
             (mob-drop-item mob item :spd nil :silent t))
    
    ;; place the corpse
    (when (and corpse
               (not (mob-ability-p mob +mob-abil-no-corpse+)))
      (let ((item) (r) (left-body-str) (left-body-type) (burns-corpse nil))
        (setf r 0)
        
        ;; determine which body part to sever (if any)
        (when (and aux-params
                   (find :chops-body-parts aux-params))
          (setf r (random 4)))

        ;; if the mob in undead and weapon is fire - no chopping
        (when (and aux-params
                   (mob-ability-p mob +mob-abil-undead+)
                   (find :is-fire aux-params))
          (setf r 0)
          (setf burns-corpse t)
          (setf dead-msg-str (format nil "~A burns to ashes. " (capitalize-name (prepend-article +article-the+ (visible-name mob))))))

        (cond
          ;; sever head
          ((= r 1) (progn
                     (place-animation (x mob) (y mob) (z mob) +anim-type-severed-body-part+ :params (list mob "head" +item-type-body-part-limb+))
                     (setf left-body-str "multilated body" left-body-type +item-type-body-part-body+)
                     (when killer
                       (setf dead-msg-str (format nil "~A chops off ~A's head. " (capitalize-name (prepend-article +article-the+ (visible-name killer))) (visible-name mob))))))
          ;; sever limb
          ((= r 2) (progn
                     (place-animation (x mob) (y mob) (z mob) +anim-type-severed-body-part+ :params (list mob "limb" +item-type-body-part-limb+))
                     (setf left-body-str "multilated body" left-body-type +item-type-body-part-body+)
                     (when killer
                       (setf dead-msg-str (format nil "~A severs ~A's limb. " (capitalize-name (prepend-article +article-the+ (visible-name killer))) (visible-name mob))))))
          ;; sever torso
          ((= r 3) (progn
                     (place-animation (x mob) (y mob) (z mob) +anim-type-severed-body-part+ :params (list mob "upper body" +item-type-body-part-half+))
                     (setf left-body-str "lower body" left-body-type +item-type-body-part-half+)
                     (when killer
                       (setf dead-msg-str (format nil "~A cuts ~A in half. " (capitalize-name (prepend-article +article-the+ (visible-name killer))) (visible-name mob))))))
          ;; do not sever anything
          (t (setf left-body-str "body" left-body-type +item-type-body-part-full+)))

        (unless burns-corpse 
          (setf item (make-instance 'item :item-type left-body-type :x (x mob) :y (y mob) :z (z mob)))
          (setf (name item) (format nil "~A's ~A" (alive-name mob) left-body-str))
          (setf (alive-name item) (format nil "~A" (alive-name mob)))
          (when (= left-body-type +item-type-body-part-full+)
            (setf (dead-mob item) (id mob)))
          (add-item-to-level-list (level *world*) item)
          (logger (format nil "MAKE-DEAD: ~A [~A] leaves ~A [~A] at (~A ~A ~A)~%" (name mob) (id mob) (name item) (id item) (x mob) (y mob) (z mob))))
        
        ))
    
    (when msg
      (print-visible-message (x mob) (y mob) (z mob) (level *world*) dead-msg-str)
      (when msg-newline (print-visible-message (x mob) (y mob) (z mob) (level *world*) (format nil "~%"))))
    
    ;; apply all on-kill abilities of the killer 
    (when killer
      
      (when (or (and (mob-ability-p killer +mob-abil-angel+)
                     (mob-ability-p mob +mob-abil-demon+))
                (and (mob-ability-p killer +mob-abil-demon+)
                     (mob-ability-p mob +mob-abil-angel+))
                (and (mob-ability-p killer +mob-abil-demon+)
                     (mob-ability-p mob +mob-abil-human+))
                (and (mob-ability-p killer +mob-abil-demon+)
                     (mob-ability-p mob +mob-abil-demon+)))
        (logger (format nil "MAKE-DEAD: ~A [~A] Real mob strength to be transferred to the killer ~A [~A] is ~A~%" (name mob) (id mob) (name killer) (id killer) (strength (get-mob-type-by-id (mob-type mob)))))
        (incf (cur-fp killer) (1+ (strength (get-mob-type-by-id (mob-type mob))))))
      
      (if (gethash (mob-type mob) (stat-kills killer))
        (incf (gethash (mob-type mob) (stat-kills killer)))
        (setf (gethash (mob-type mob) (stat-kills killer)) 1))
      
      (let ((abil-list nil))
        ;; collect all passive on-kill abilities
        (setf abil-list (loop for abil-type-id in (get-mob-all-abilities killer)
                              when (and (abil-passive-p abil-type-id)
                                        (abil-on-kill-p abil-type-id))
                                collect abil-type-id))
        ;; invoke all applicable abilities
        (loop for abil-type-id in abil-list
              when (can-invoke-ability killer mob abil-type-id)
                do
                   (mob-invoke-ability killer mob abil-type-id))
        )) 

    (when (or (and (null (master-mob-id mob))
                   (null (slave-mob-id mob)))
              (and (null (master-mob-id mob))
                   (slave-mob-id mob)))
      (remove-mob-from-level-list (level *world*) mob))
    ;;(remove-mob-from-level-list (level *world*) mob)

    ;; if the target is being ridden, dismount the rider
    (when (mounted-by-mob-id mob)
      (setf (riding-mob-id (get-mob-by-id (mounted-by-mob-id mob))) nil)
      (adjust-dodge (get-mob-by-id (mounted-by-mob-id mob)))
      (add-mob-to-level-list (level *world*) (get-mob-by-id (mounted-by-mob-id mob)))
      (setf (mounted-by-mob-id mob) nil))
    ;; if the target is riding something, place back the mount on map
    (when (riding-mob-id mob)
      (setf (mounted-by-mob-id (get-mob-by-id (riding-mob-id mob))) nil)
      (setf (x (get-mob-by-id (riding-mob-id mob))) (x mob)
            (y (get-mob-by-id (riding-mob-id mob))) (y mob))
      (add-mob-to-level-list (level *world*) (get-mob-by-id (riding-mob-id mob)))
      (setf (riding-mob-id mob) nil))

    
    
    ;; place blood stain if req
    (when (and splatter (< (random 100) 75))
      (add-feature-to-level-list (level *world*) (make-instance 'feature :feature-type +feature-blood-stain+ :x (x mob) :y (y mob) :z (z mob))))
    
    (setf (dead= mob) t)))

(defun mob-evolve (mob)
  (print-visible-message (x mob) (y mob) (z mob) (level *world*) (format nil "~A assumes a superior form of ~A! " (capitalize-name (prepend-article +article-the+ (name mob))) (prepend-article +article-a+ (name (get-mob-type-by-id (evolve-into mob))))))
  
  (setf (mob-type mob) (evolve-into mob))
  (setf (cur-hp mob) (max-hp mob))
  (setf (cur-fp mob) 0)
  
  (setf (cur-sight mob) (base-sight mob))
  
  (setf (face-mob-type-id mob) (mob-type mob))
  (when (= (mob-type mob) +mob-type-demon+) 
    (set-name mob)
    (unless (eq mob *player*)
      (print-visible-message (x mob) (y mob) (z mob) (level *world*) (format nil "It will be hereby known as ~A! " (name mob)))))
  
  (set-cur-weapons mob)
  (adjust-dodge mob)
  (adjust-armor mob)
  (adjust-m-acc mob)
  (adjust-r-acc mob)
  (adjust-sight mob)

  ;; if the mob has no climbing ability - disable it
  (when (not (mob-ability-p mob +mob-abil-climbing+))
    (rem-mob-effect mob +mob-effect-climbing-mode+))
  
  (when (mob-effect-p mob +mob-effect-possessed+)
    (setf (cur-hp (get-mob-by-id (slave-mob-id mob))) 0)
    (make-dead (get-mob-by-id (slave-mob-id mob)) :splatter nil :msg nil :msg-newline nil :corpse nil :aux-params ())
    (add-feature-to-level-list (level *world*) (make-instance 'feature :feature-type +feature-blood-stain+ :x (x mob) :y (y mob)))
    (print-visible-message (x mob) (y mob) (z mob) (level *world*) (format nil "Its ascension destroyed its vessel."))
    
    (rem-mob-effect mob +mob-effect-possessed+)
    (setf (master-mob-id mob) nil)
    (setf (slave-mob-id mob) nil)
    )

  (incf-mob-motion mob *mob-motion-ascend*)

  (generate-sound mob (x mob) (y mob) (z mob) *mob-sound-ascend* #'(lambda (str)
                                                                     (format nil "You hear some eerie sounds~A." str)))
  
  (print-visible-message (x mob) (y mob) (z mob) (level *world*) (format nil "~%")))

(defmethod on-tick ((mob mob))
     
  (when (< (cur-fp mob) 0)
    (setf (cur-fp mob) 0))

  ;; a special case for revealing demons & angels that ride fiends & gargantaur
  (when (and (riding-mob-id mob)
             (or (mob-ability-p (get-mob-by-id (riding-mob-id mob)) +mob-abil-demon+)
                 (mob-ability-p (get-mob-by-id (riding-mob-id mob)) +mob-abil-angel+)))
    (if (mob-effect-p mob +mob-effect-reveal-true-form+)
      (when (eq (cd (get-effect-by-id (mob-effect-p mob +mob-effect-reveal-true-form+))) 1)
        (setf (cd (get-effect-by-id (mob-effect-p mob +mob-effect-reveal-true-form+))) 2))
      (set-mob-effect mob :effect-type-id +mob-effect-reveal-true-form+ :actor-id (id mob) :cd 2)))

  (let ((was-flying (if (mob-effect-p mob +mob-effect-flying+)
                      t
                      nil)))
  
    (loop for effect-id being the hash-value in (effects mob)
          for effect = (get-effect-by-id effect-id)
          with was-flying = nil
          when (not (eq (cd effect) t))
            do
               (decf (cd effect))
               
               (when (zerop (cd effect))
                 (when (= (effect-type effect) +mob-effect-flying+)
                   (setf was-flying t))
                 (rem-mob-effect mob (effect-type effect))))
    
    (when (and was-flying
               (not (mob-effect-p mob +mob-effect-flying+))
               (not (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-water+))
               (apply-gravity mob))
      (set-mob-location mob (x mob) (y mob) (z mob)))
    )
  
  (loop for effect-id being the hash-value in (effects mob)
        for effect = (get-effect-by-id effect-id)
        do
           (funcall (on-tick (get-effect-type-by-id (effect-type effect))) effect mob))
           

  (loop for ability-id being the hash-key in (abilities-cd mob)
        when (not (zerop (abil-cur-cd-p mob ability-id)))
          do
             (set-abil-cur-cd mob ability-id (1- (abil-cur-cd-p mob ability-id))))
  
  (adjust-dodge mob)
  (adjust-armor mob)
  (adjust-m-acc mob)
  (adjust-r-acc mob)
  (adjust-sight mob)
  
  (when (and (evolve-into mob)
             (>= (cur-fp mob) (max-fp mob)))
    (mob-evolve mob))

  ;; if the mob has climbing ability - turn it on, if disabled
  (when (and (mob-ability-p mob +mob-abil-climbing+)
             (not (mob-effect-p mob +mob-effect-climbing-mode+))
             (not (mob-effect-p mob +mob-effect-sprint+)))
    (set-mob-effect mob :effect-type-id +mob-effect-climbing-mode+ :actor-id (id mob) :cd t))

  (if (or (mob-ability-p mob +mob-abil-no-breathe+)
          (not (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-water+))
          (and (< (z mob) (1- (array-dimension (terrain (level *world*)) 2)))
               (not (or (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (1+ (z mob))) +terrain-trait-water+)
                        (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (1+ (z mob))) +terrain-trait-opaque-floor+)
                        (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (1+ (z mob))) +terrain-trait-blocks-move+)))))
    (progn
      (setf (cur-oxygen mob) *max-oxygen-level*))
    (progn
      (when (> (cur-oxygen mob) 0)
        (decf (cur-oxygen mob)))
      (when (zerop (cur-oxygen mob))
        (decf (cur-hp mob) *lack-oxygen-dmg*)
        (print-visible-message (x mob) (y mob) (z mob) (level *world*) (format nil "~A can not breath and takes ~A dmg. " (capitalize-name (prepend-article +article-the+ (visible-name mob))) *lack-oxygen-dmg*) :observed-mob mob)
        (when (check-dead mob)
          (when (eq mob *player*)
            (setf (killed-by *player*) "drowning"))
          (make-dead mob :splatter nil :msg t)
          (when (mob-effect-p mob +mob-effect-possessed+)
            (setf (cur-hp (get-mob-by-id (slave-mob-id mob))) 0)
            (setf (x (get-mob-by-id (slave-mob-id mob))) (x mob)
                  (y (get-mob-by-id (slave-mob-id mob))) (y mob)
                  (z (get-mob-by-id (slave-mob-id mob))) (z mob))
            (make-dead (get-mob-by-id (slave-mob-id mob)) :splatter nil :msg nil :msg-newline nil :corpse nil :aux-params ())))
        (print-visible-message (x mob) (y mob) (z mob) (level *world*) (format nil "~%") :observed-mob mob))))
  
  
  )
  

(defun get-current-mob-glyph-idx (mob &key (x (x mob)) (y (y mob)) (z (z mob)))
  (declare (ignore z))
  (cond  
    ((and (> (map-size mob) 1)
          (= (+ (x mob) (car (momentum-dir mob))) x) (= (+ (y mob) (cdr (momentum-dir mob))) y)
          (= (x-y-into-dir (car (momentum-dir mob)) (cdr (momentum-dir mob))) 3))
     114)
    ((and (> (map-size mob) 1)
          (= (+ (x mob) (car (momentum-dir mob))) x) (= (+ (y mob) (cdr (momentum-dir mob))) y)
          (= (x-y-into-dir (car (momentum-dir mob)) (cdr (momentum-dir mob))) 1))
     115)
    ((and (> (map-size mob) 1)
          (= (+ (x mob) (car (momentum-dir mob))) x) (= (+ (y mob) (cdr (momentum-dir mob))) y)
          (= (x-y-into-dir (car (momentum-dir mob)) (cdr (momentum-dir mob))) 9))
     116)
    ((and (> (map-size mob) 1)
          (= (+ (x mob) (car (momentum-dir mob))) x) (= (+ (y mob) (cdr (momentum-dir mob))) y)
          (= (x-y-into-dir (car (momentum-dir mob)) (cdr (momentum-dir mob))) 7))
     117)
    ((and (> (map-size mob) 1)
          (= (+ (x mob) (car (momentum-dir mob))) x) (= (+ (y mob) (cdr (momentum-dir mob))) y)
          (= (x-y-into-dir (car (momentum-dir mob)) (cdr (momentum-dir mob))) 6))
     112)
    ((and (> (map-size mob) 1)
          (= (+ (x mob) (car (momentum-dir mob))) x) (= (+ (y mob) (cdr (momentum-dir mob))) y)
          (= (x-y-into-dir (car (momentum-dir mob)) (cdr (momentum-dir mob))) 4))
     113)
    ((and (> (map-size mob) 1)
          (= (+ (x mob) (car (momentum-dir mob))) x) (= (+ (y mob) (cdr (momentum-dir mob))) y)
          (= (x-y-into-dir (car (momentum-dir mob)) (cdr (momentum-dir mob))) 2))
     111)
    ((and (> (map-size mob) 1)
          (= (+ (x mob) (car (momentum-dir mob))) x) (= (+ (y mob) (cdr (momentum-dir mob))) y)
          (= (x-y-into-dir (car (momentum-dir mob)) (cdr (momentum-dir mob))) 8))
     110)
    ((and (> (map-size mob) 1)
          (= (- (x mob) x) (* -1 (truncate (1- (map-size mob)) 2)))
          (= (- (y mob) y) (* -1 (truncate (1- (map-size mob)) 2))))
     106)
    ((and (> (map-size mob) 1)
          (= (- (x mob) x) (* 1 (truncate (1- (map-size mob)) 2)))
          (= (- (y mob) y) (* -1 (truncate (1- (map-size mob)) 2))))
     107)
    ((and (> (map-size mob) 1)
          (= (- (x mob) x) (* -1 (truncate (1- (map-size mob)) 2)))
          (= (- (y mob) y) (* 1 (truncate (1- (map-size mob)) 2))))
     105)
    ((and (> (map-size mob) 1)
          (= (- (x mob) x) (* 1 (truncate (1- (map-size mob)) 2)))
          (= (- (y mob) y) (* 1 (truncate (1- (map-size mob)) 2))))
     104)
    ((and (> (map-size mob) 1)
          (or (= (- (x mob) x) (* 1 (truncate (1- (map-size mob)) 2)))
              (= (- (x mob) x) (* -1 (truncate (1- (map-size mob)) 2)))))
     108)
    ((and (> (map-size mob) 1)
          (or (= (- (y mob) y) (* 1 (truncate (1- (map-size mob)) 2)))
              (= (- (y mob) y) (* -1 (truncate (1- (map-size mob)) 2)))))
     109)
    ((and (> (map-size mob) 1)
          (or (/= (- (x mob) x) 0)
              (/= (- (y mob) y) 0)))
     0)
    ;((and (mob-effect-p mob +mob-effect-possessed+)
    ;      (mob-effect-p mob +mob-effect-reveal-true-form+))
    ; (glyph-idx (get-mob-type-by-id (mob-type (get-mob-by-id (slave-mob-id mob))))))
    (t (glyph-idx (get-mob-type-by-id (face-mob-type-id mob))))))

(defun get-current-mob-glyph-color (mob)
  (cond
    ((and (mob-effect-p mob +mob-effect-possessed+)
          (mob-effect-p mob +mob-effect-reveal-true-form+))
     (glyph-color (get-mob-type-by-id (mob-type mob)))
     )
    ((and (or (mob-effect-p mob +mob-effect-possessed+)
              (mob-effect-p mob +mob-effect-disguised+))
          (= (faction *player*) (faction mob)))
     (glyph-color (get-mob-type-by-id (mob-type mob))))
    ((and (mob-ability-p *player* +mob-abil-angel+)
          (= (faction *player*) (faction mob)))
     (glyph-color (get-mob-type-by-id (mob-type mob))))
    ((mob-effect-p mob +mob-effect-blessed+)
     sdl:*blue*)
    (t (glyph-color (get-mob-type-by-id (face-mob-type-id mob))))))

(defun get-current-mob-back-color (mob)
  (back-color (get-mob-type-by-id (face-mob-type-id mob))))

(defun get-current-mob-name (mob)
  (cond
    ;; player always knows himself
    ((eq mob *player*)
     (get-qualified-name mob))
    ;; revealed demons show their true name
    ((and (mob-effect-p mob +mob-effect-possessed+)
          (mob-effect-p mob +mob-effect-reveal-true-form+))
     (get-qualified-name mob))
    ;; demons know true names of each other
    ((and (mob-ability-p mob +mob-abil-demon+)
          (mob-ability-p *player* +mob-abil-demon+))
     (get-qualified-name mob))
    ;; angels know true names of each other
    ((and (mob-ability-p mob +mob-abil-angel+)
          (mob-ability-p *player* +mob-abil-angel+))
     (get-qualified-name mob))
    ;; in all other cases see current appearence name
    (t (name (get-mob-type-by-id (face-mob-type-id mob))))))


(defgeneric on-bump (target actor))

(defun sense-evil ()
  (setf (sense-evil-id *player*) nil)
  (let ((nearest-enemy))
    (setf nearest-enemy (loop for mob-id in (mob-id-list (level *world*))
                              for mob = (get-mob-by-id mob-id)
                              with nearest-mob = nil
                              when (and (not (check-dead mob))
                                        (mob-ability-p mob +mob-abil-demon+))
                                do
                                   (unless nearest-mob (setf nearest-mob mob))
                                   (when (< (get-distance (x *player*) (y *player*) (x mob) (y mob))
                                            (get-distance (x *player*) (y *player*) (x nearest-mob) (y nearest-mob)))
                                     (setf nearest-mob mob))
                              finally (return nearest-mob)))
    (if nearest-enemy
      (setf (sense-evil-id *player*) (id nearest-enemy))
      (setf (sense-evil-id *player*) nil))))

(defun sense-good ()
  (let ((nearest-enemy))
    (setf nearest-enemy (loop for mob-id in (mob-id-list (level *world*))
                              for mob = (get-mob-by-id mob-id)
                              with nearest-mob = nil
                              when (and (not (check-dead mob))
                                        (mob-ability-p mob +mob-abil-angel+))
                                do
                                   (unless nearest-mob (setf nearest-mob mob))
                                   (when (< (get-distance (x *player*) (y *player*) (x mob) (y mob))
                                            (get-distance (x *player*) (y *player*) (x nearest-mob) (y nearest-mob)))
                                     (setf nearest-mob mob))
                              finally (return nearest-mob)))
    (if nearest-enemy
      (setf (sense-good-id *player*) (id nearest-enemy))
      (setf (sense-good-id *player*) nil))))

(defun mob-pick-item (mob item &key (spd (move-spd (get-mob-type-by-id (mob-type mob)))) (silent nil))
  (logger (format nil "MOB-PICK-ITEM: ~A [~A] picks up ~A [~A]~%" (name mob) (id mob) (name item) (id item)))
  (if (null (inv-id item))
    (progn
      (unless silent
        (incf-mob-motion mob *mob-motion-pick-drop*)
        ;; generate sound
        (generate-sound mob (x mob) (y mob) (z mob) *mob-sound-pick-drop* #'(lambda (str)
                                                                              (format nil "You hear rustling~A. " str)))
        (print-visible-message (x mob) (y mob) (z mob) (level *world*)
                               (format nil "~A picks up ~A. "
                                       (capitalize-name (prepend-article +article-the+ (visible-name mob)))
                                       (cond
                                         ((> (qty item) 1) (format nil "~A ~A" (qty item) (plural-name item)))
                                         (t (format nil "~A" (prepend-article +article-a+ (name item))))))
                               :observed-mob mob))
      (remove-item-from-level-list (level *world*) item)
      (setf (inv mob) (add-to-inv item (inv mob) (id mob)))
      
      (when spd
        (make-act mob spd)))
    (progn
      (logger (format nil "MOB-PICK-ITEM: Pick up failed, item is not on the ground!~%" )))))

(defun mob-drop-item (mob item &key (qty (qty item)) (spd (move-spd (get-mob-type-by-id (mob-type mob)))) silent)
  (logger (format nil "MOB-DROP-ITEM: ~A [~A] drops ~A [~A]~%" (name mob) (id mob) (name item) (id item)))
  (if (eq (inv-id item) (id mob))
    (progn
      
      (setf (inv mob) (remove-from-inv item (inv mob) :qty qty))
      (setf (x item) (x mob) (y item) (y mob) (z item) (z mob))
      (add-item-to-level-list (level *world*) item)

      (unless silent
        (incf-mob-motion mob *mob-motion-pick-drop*)
        ;; generate sound
        (generate-sound mob (x mob) (y mob) (z mob) *mob-sound-pick-drop* #'(lambda (str)
                                                                              (format nil "You hear rustling~A. " str)))
        (print-visible-message (x mob) (y mob) (z mob) (level *world*)
                               (format nil "~A drops ~A. "
                                       (capitalize-name (prepend-article +article-the+ (visible-name mob)))
                                       (cond
                                         ((> (qty item) 1) (format nil "~A ~A" (qty item) (plural-name item)))
                                         (t (format nil "~A" (prepend-article +article-a+ (name item))))))
                             :observed-mob mob))
      (when spd
        (make-act mob spd)))
    (progn
      (logger (format nil "MOB-DROP-ITEM: Drop failed, item is not in the mob's inventory!~%" )))))

(defun ignite-tile (level x y z src-x src-y src-z)
  (when (get-terrain-type-trait (get-terrain-* level x y z) +terrain-trait-flammable+)
    (add-feature-to-level-list level (make-instance 'feature :feature-type +feature-fire+ :x x :y y :z z :counter (get-terrain-type-trait (get-terrain-* level x y z) +terrain-trait-flammable+)))
    (if (get-terrain-type-trait (get-terrain-* level x y z) +terrain-trait-opaque-floor+)
      (progn
        (set-terrain-* level x y z +terrain-floor-ash+)
        ;(check-surroundings x y nil #'(lambda (dx dy)
        ;                                (when (and (get-connect-map-value (aref (connect-map level) 1) dx dy z +connect-map-move-walk+)
        ;                                           (get-terrain-type-trait (get-terrain-* level dx dy z) +terrain-trait-opaque-floor+))
        ;                                  (set-connect-map-value (aref (connect-map level) 1) x y z +connect-map-move-walk+
        ;                                                         (get-connect-map-value (aref (connect-map level) 1) dx dy z +connect-map-move-walk+)))
        ;                                (when (and (get-connect-map-value (aref (connect-map level) 1) dx dy z +connect-map-move-climb+)
        ;                                           (get-terrain-type-trait (get-terrain-* level dx dy z) +terrain-trait-opaque-floor+))
        ;                                  (set-connect-map-value (aref (connect-map level) 1) x y z +connect-map-move-climb+
        ;                                                         (get-connect-map-value (aref (connect-map level) 1) dx dy z +connect-map-move-climb+)))))
       
        )
      (progn
        (set-terrain-* level x y z +terrain-floor-air+)
        ))
     (set-connect-map-value (aref (connect-map level) 1) x y z +connect-map-move-walk+
                            (get-connect-map-value (aref (connect-map level) 1) src-x src-y src-z +connect-map-move-walk+))
     (set-connect-map-value (aref (connect-map level) 1) x y z +connect-map-move-climb+
                            (get-connect-map-value (aref (connect-map level) 1) src-x src-y src-z +connect-map-move-climb+))
     (set-connect-map-value (aref (connect-map level) 1) x y z +connect-map-move-fly+
                            (get-connect-map-value (aref (connect-map level) 1) src-x src-y src-z +connect-map-move-fly+))
    ))

(defun calculate-player-score (bonus)
  (let ((score (+ (cur-score *player*) bonus (- (if (> (real-game-time *world*) 200)
                                                  (- (real-game-time *world*) 200)
                                                  0))
                  (if (= (mob-type *player*) +mob-type-thief+)
                    (calculate-total-value *player*)
                    0))))
    (when (< score 0)
      (setf score 0))
    score))

(defun adjust-disguise-for-mob (mob)
  (setf (face-mob-type-id mob) (mob-type mob))
  (when (mob-effect-p mob +mob-effect-divine-concealed+)
    (setf (face-mob-type-id mob) +mob-type-man+))
  (when (and (mob-ability-p mob +mob-abil-demon+)
             (slave-mob-id mob)
             (not (mob-effect-p mob +mob-effect-reveal-true-form+)))
    (setf (face-mob-type-id mob) (mob-type (get-mob-by-id (slave-mob-id mob)))))
  (when (mob-effect-p mob +mob-effect-disguised+)
    (setf (face-mob-type-id mob) (param1 (get-effect-by-id (mob-effect-p mob +mob-effect-disguised+))))))

;;-------------------------------
;; Common cards & abilities funcs
;;-------------------------------

(defun invoke-bend-space (actor)
  (logger (format nil "MOB-BEND-SPACE: ~A [~A] invokes bend space.~%" (name actor) (id actor)))
  (let ((applicable-tiles ())
        (dx) (dy) (dz) (r))
    (loop for dx of-type fixnum from (- (x actor) 6) to (+ (x actor) 6) do
      (loop for dy of-type fixnum from (- (y actor) 6) to (+ (y actor) 6) do
        (loop for dz of-type fixnum from (- (z actor) 6) to (+ (z actor) 6)
              when (and (>= dx 0) (< dx (array-dimension (terrain (level *world*)) 0))
                        (>= dy 0) (< dy (array-dimension (terrain (level *world*)) 1))
                        (>= dz 0) (< dz (array-dimension (terrain (level *world*)) 2))
                        (eq (check-move-on-level actor dx dy dz) t)
                        (or (get-terrain-type-trait (get-terrain-* (level *world*) dx dy dz) +terrain-trait-opaque-floor+)
                            (get-terrain-type-trait (get-terrain-* (level *world*) dx dy dz) +terrain-trait-water+)))
                do
                   (push (list dx dy dz) applicable-tiles))))
    (when applicable-tiles
      (setf r (random (length applicable-tiles)))
      (setf dx (first (nth r applicable-tiles))
            dy (second (nth r applicable-tiles))
            dz (third (nth r applicable-tiles))))
    (logger (format nil "MOB-BEND-SPACE: ~A [~A] teleports to (~A ~A ~A).~%" (name actor) (id actor) dx dy dz))
    (generate-sound actor (x actor) (y actor) (z actor) 80 #'(lambda (str)
                                                               (format nil "You hear crackling~A. " str)))
    (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                           (format nil "~A disappeares in thin air. " (capitalize-name (prepend-article +article-the+ (visible-name actor)))))
    
    (set-mob-location actor dx dy dz)
    
    (generate-sound actor (x actor) (y actor) (z actor) 80 #'(lambda (str)
                                                               (format nil "You hear crackling~A. " str)))
    (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                           (format nil "~A appears out of thin air. " (capitalize-name (prepend-article +article-the+ (visible-name actor)))))
    ))

(defun invoke-teleport-self (actor min-distance z)
  (logger (format nil "MOB-TELEPORT-SELF: ~A [~A] teleports self~%" (name actor) (id actor)))

  (let ((max-x (array-dimension (terrain (level *world*)) 0))
        (max-y (array-dimension (terrain (level *world*)) 1))
        (rx (- (+ 80 (x actor))
               (1+ (random 160)))) 
        (ry (- (+ 80 (y actor))
               (1+ (random 160))))
        (n 2000))
    ;; 2000 hundred tries to find a suitable place for teleport
    (loop while (or (< rx 0) (< ry 0) (>= rx max-x) (>= ry max-y)
                    (< (get-distance (x actor) (y actor) rx ry) min-distance)
                    (not (get-terrain-type-trait (get-terrain-* (level *world*) rx ry z) +terrain-trait-opaque-floor+))
                    (not (eq (check-move-on-level actor rx ry z) t))
                    (= (get-level-connect-map-value (level *world*) rx ry z (if (riding-mob-id actor)
                                                                              (map-size (get-mob-by-id (riding-mob-id actor)))
                                                                              (map-size actor))
                                                    (get-mob-move-mode actor))
                       +connect-room-none+))
          do
             ;(format t "RX = ~A, RX = ~A, DIST = ~A, TERRAIN-FLOOR = ~A, CHECK-MOVE = ~A, CONNECT = ~A~%"
             ;        rx ry (get-distance (x actor) (y actor) rx ry)
             ;        (if (and (>= rx 0) (>= ry 0) (< rx max-x) (< ry max-y))
             ;          (get-terrain-type-trait (get-terrain-* (level *world*) rx ry (z actor)) +terrain-trait-opaque-floor+)
             ;          nil)
             ;        (if (and (>= rx 0) (>= ry 0) (< rx max-x) (< ry max-y))
             ;          (check-move-on-level actor rx ry (z actor))
             ;          nil)
             ;        (if (and (>= rx 0) (>= ry 0) (< rx max-x) (< ry max-y))
             ;          (get-level-connect-map-value (level *world*) rx ry (z actor) (if (riding-mob-id actor)
             ;                                                                         (map-size (get-mob-by-id (riding-mob-id actor)))
             ;                                                                         (map-size actor))
             ;                                       (get-mob-move-mode actor))
             ;          nil))
             (decf n)
             (when (zerop n)
               (loop-finish))
             (setf rx (- (+ 80 (x actor))
                         (1+ (random 160))))
             (setf ry (- (+ 80 (y actor))
                         (1+ (random 160)))))
    
    (if (not (zerop n))
      (progn
        (generate-sound actor (x actor) (y actor) (z actor) 120 #'(lambda (str)
                                                                    (format nil "You hear crackling~A." str)))
        (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                               (format nil "~A disappeares in thin air. " (capitalize-name (prepend-article +article-the+ (visible-name actor)))))
        (set-mob-location actor rx ry z)
        (generate-sound actor (x actor) (y actor) (z actor) 120 #'(lambda (str)
                                                                    (format nil "You hear crackling~A." str)))
        (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                               (format nil "~A appears out of thin air. " (capitalize-name (prepend-article +article-the+ (visible-name actor))))))
      (progn
        (generate-sound actor (x actor) (y actor) (z actor) 120 #'(lambda (str)
                                                                    (format nil "You hear crackling~A." str)))
        (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                               (format nil "~A blinks for a second, but remains in place. " (capitalize-name (prepend-article +article-the+ (visible-name actor)))))))
    ))

(defun invoke-disguise (actor)
  (generate-sound actor (x actor) (y actor) (z actor) 30 #'(lambda (str)
                                                             (format nil "You hear some hiss~A. " str)))
  (let ((face-mob-type-id (if (zerop (random 2))
                            +mob-type-man+
                            +mob-type-woman+)))
  
    (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                           (format nil "~A disguises itself as ~A. " (capitalize-name (prepend-article +article-the+ (visible-name actor))) (prepend-article +article-a+ (name (get-mob-type-by-id face-mob-type-id)))))
    (set-mob-effect actor :effect-type-id +mob-effect-disguised+ :actor-id (id actor) :param1 face-mob-type-id)
    (adjust-disguise-for-mob actor)))

(defun invoke-curse (actor)
    
  (let ((enemy-list nil))
    (when (zerop (random 2))
      ;; 1/2th chance to do anything
      
      ;; collect all unholy enemies in sight
      (setf enemy-list (loop for enemy-mob-id in (visible-mobs actor)
                             when (not (get-faction-relation (faction actor) (faction (get-mob-by-id enemy-mob-id))))
                               collect enemy-mob-id))
      
      (logger (format nil "MOB-CURSE: ~A [~A] affects the following enemies ~A with the curse~%" (name actor) (id actor) enemy-list))
      
      ;; place a curse on them for 5 turns
      (loop for enemy-mob-id in enemy-list
            with protected = nil
            do
               (setf protected nil)
               ;; divine shield and blessings also grant one-time protection from curses
               (when (and (not protected) (mob-effect-p (get-mob-by-id enemy-mob-id) +mob-effect-blessed+))
                 (rem-mob-effect (get-mob-by-id enemy-mob-id) +mob-effect-blessed+)
                 (setf protected t))
               
               (when (and (not protected) (mob-effect-p (get-mob-by-id enemy-mob-id) +mob-effect-divine-shield+))
                 (rem-mob-effect (get-mob-by-id enemy-mob-id) +mob-effect-divine-shield+)
                 (setf protected t))
               
               (if protected
                 (progn
                   (logger (format nil "MOB-CURSE: ~A [~A] was protected, so the curse removes protection only~%" (name (get-mob-by-id enemy-mob-id)) (id (get-mob-by-id enemy-mob-id))))
                   (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                          (format nil "~A's curse removed divine protection from ~A. "
                                                  (capitalize-name (prepend-article +article-the+ (visible-name actor)))
                                                  (prepend-article +article-the+ (visible-name (get-mob-by-id enemy-mob-id)))))
                   )
                 (progn
                   (logger (format nil "MOB-CURSE: ~A [~A] affects the enemy ~A with a curse~%" (name actor) (id actor) (get-mob-by-id enemy-mob-id)))
                   (set-mob-effect (get-mob-by-id enemy-mob-id) :effect-type-id +mob-effect-cursed+ :actor-id (id actor) :cd 5)
                   (print-visible-message (x actor) (y actor) (z actor) (level *world*) 
                                          (format nil "~A is cursed. " (capitalize-name (prepend-article +article-the+ (visible-name (get-mob-by-id enemy-mob-id))))))))
            )
      
      )))

(defun invoke-fear (actor fear-strength)
  (logger (format nil "MOB-INSTILL-FEAR: ~A [~A] casts instill fear.~%" (name actor) (id actor)))
  ;; fear nearby visible enemy mobs
  ;; fear can be resisted depending on the strength of the mob
  (loop for i from 0 below (length (visible-mobs actor))
        for mob = (get-mob-by-id (nth i (visible-mobs actor)))
        when (not (get-faction-relation (faction actor) (faction mob)))
          do
             (if (> (random (+ (strength mob) fear-strength)) (strength mob))
               (progn
                 (set-mob-effect mob :effect-type-id +mob-effect-fear+ :actor-id (id actor) :cd 3)
                 (print-visible-message (x mob) (y mob) (z mob) (level *world*) 
                                        (format nil "~A is feared. " (capitalize-name (prepend-article +article-the+ (visible-name mob))))
                                        :observed-mob mob))
               (progn
                 (print-visible-message (x mob) (y mob) (z mob) (level *world*) 
                                        (format nil "~A resists fear. " (capitalize-name (prepend-article +article-the+ (visible-name mob))))
                                        :observed-mob mob)))))

(defun set-mob-piety (mob piety-num)
  (when (worshiped-god mob)
    (let ((old-piety (get-worshiped-god-piety (worshiped-god mob))))
      (cond
        ((< piety-num 0) (setf piety-num 0))
        ((> piety-num 200) (setf piety-num 200)))
      (setf (second (worshiped-god mob)) piety-num)
      (when (and (eq mob *player*)
                 (check-piety-level-changed (get-worshiped-god-type (worshiped-god mob))
                                            old-piety (get-worshiped-god-piety (worshiped-god mob))))
        (print-visible-message (x mob) (y mob) (z mob) (level *world*) (return-piety-change-str (get-worshiped-god-type (worshiped-god mob)) (get-worshiped-god-piety (worshiped-god mob)) old-piety))))))
