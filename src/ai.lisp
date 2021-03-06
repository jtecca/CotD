(in-package :cotd)

(defgeneric ai-function (mob))

(defun check-move-for-ai (mob dx dy dz cx cy cz &key (final-dst nil))
  (declare (optimize (speed 3))
           (type fixnum dx dy dz cx cy cz))
  (let ((sx 0) (sy 0) (move-result nil)
        (map-size (if (riding-mob-id mob)
                    (map-size (get-mob-by-id (riding-mob-id mob)))
                    (map-size mob))))
    (declare (type fixnum sx sy map-size))
    ;; calculate the coords of the mob's NE corner
    (setf sx (- dx (truncate (1- map-size) 2)))
    (setf sy (- dy (truncate (1- map-size) 2)))

    (loop for nx of-type fixnum from sx below (+ sx map-size) do
      (loop for ny of-type fixnum from sy below (+ sy map-size) do
        ;; cant move beyond level borders 
        (when (or (< nx 0) (< ny 0) (< dz 0) (>= nx (array-dimension (terrain (level *world*)) 0)) (>= ny (array-dimension (terrain (level *world*)) 1)) (>= dz (array-dimension (terrain (level *world*)) 2)))
          (return-from check-move-for-ai nil))

        (setf move-result nil)

        ;; can move if not impassable 
        (when (not (get-terrain-type-trait (get-terrain-* (level *world*) nx ny dz) +terrain-trait-blocks-move+))
          (setf move-result t))

        ;; can move if a door (not important if open or closed)
        (when (get-terrain-type-trait (get-terrain-* (level *world*) nx ny dz) +terrain-trait-openable-door+)
          (setf move-result t))

        ;; can move if a window & you can open windows
        (when (and (get-terrain-type-trait (get-terrain-* (level *world*) nx ny dz) +terrain-trait-openable-window+)
                   (mob-ability-p mob +mob-abil-open-close-window+))
          (setf move-result t))

        (unless move-result
          (return-from check-move-for-ai nil))
        
        (setf move-result nil)

        ;; can go anywhere horizontally or directly up/below if the current tile is water 
        (when (and (or (= (- cz dz) 0)
                       (and (/= (- cz dz) 0)
                            (= nx cx)
                            (= ny cy))
                       )
                   (get-terrain-type-trait (get-terrain-* (level *world*) cx cy cz) +terrain-trait-water+)
                   (get-terrain-type-trait (get-terrain-* (level *world*) nx ny dz) +terrain-trait-water+))
          (setf move-result t))
        
        ;; can go from down to up if the source tile is water and the landing tile has floor and is not directly above the source tile
        (when (and (> (- dz cz) 0)
                   (not (and (= cx nx)
                             (= cy ny)))
                   (not (get-terrain-type-trait (get-terrain-* (level *world*) nx ny dz) +terrain-trait-blocks-move+))
                   (get-terrain-type-trait (get-terrain-* (level *world*) nx ny cz) +terrain-trait-blocks-move+)
                   (get-terrain-type-trait (get-terrain-* (level *world*) cx cy cz) +terrain-trait-water+)
                   (not (get-terrain-type-trait (get-terrain-* (level *world*) cx cy (1+ cz)) +terrain-trait-opaque-floor+)))
          (setf move-result t))

        ;; can go from up to down if the landing tile is water and is not directly below the source tile
        (when (and (< (- dz cz) 0)
                   (or (/= (- dx cx) 0)
                       (/= (- dy cy) 0))
                   (get-terrain-type-trait (get-terrain-* (level *world*) nx ny dz) +terrain-trait-water+)
                   (not (get-terrain-type-trait (get-terrain-* (level *world*) nx ny cz) +terrain-trait-opaque-floor+))
                   (not (get-terrain-type-trait (get-terrain-* (level *world*) nx ny cz) +terrain-trait-water+)))
          (setf move-result t))
        
        ;; can go from down to up if the source tile is slope up and the landing tile has floor and is not directly above the source tile
        (when (and (> (- dz cz) 0)
                   (not (and (= cx nx)
                             (= cy ny)))
                   (get-terrain-type-trait (get-terrain-* (level *world*) nx ny dz) +terrain-trait-opaque-floor+)
                   (get-terrain-type-trait (get-terrain-* (level *world*) nx ny cz) +terrain-trait-blocks-move+)
                   (get-terrain-type-trait (get-terrain-* (level *world*) cx cy cz) +terrain-trait-slope-up+)
                   (not (get-terrain-type-trait (get-terrain-* (level *world*) cx cy (1+ cz)) +terrain-trait-opaque-floor+)))
          (setf move-result t))

        ;; can go from up to down if the landing tile is floor and is not directly below the source tile
        (when (and (< (- dz cz) 0)
                   (or (/= (- dx cx) 0)
                       (/= (- dy cy) 0))
                   (get-terrain-type-trait (get-terrain-* (level *world*) nx ny dz) +terrain-trait-opaque-floor+)
                   (not (get-terrain-type-trait (get-terrain-* (level *world*) nx ny cz) +terrain-trait-opaque-floor+)))
          (setf move-result t))

        ;; can go from horizontally if the landing tile has opaque floor and there is no final destination
        ;; or can go horizontally if the landing tile has opaque floor and it is NOT the final distination
        ;; or can go horizontally if the landing tile is the final destination (and we do not care about the floor)
        (when (or (and (= (- dz cz) 0)
                       (get-terrain-type-trait (get-terrain-* (level *world*) nx ny dz) +terrain-trait-opaque-floor+)
                       (not final-dst))
                  (and (= (- dz cz) 0)
                       final-dst
                       (get-terrain-type-trait (get-terrain-* (level *world*) nx ny dz) +terrain-trait-opaque-floor+)
                       (not (and (= nx (first final-dst))
                                 (= ny (second final-dst))
                                 (= dz (third final-dst)))))
                  (and (= (- dz cz) 0)
                       final-dst
                       (and (= nx (first final-dst))
                            (= ny (second final-dst))
                            (= dz (third final-dst)))))
          (setf move-result t))

        ;; you can go anywhere horizontaly or directly up/down if you are climbing and there is a wall or floor next to you
        (when (and (not move-result)
                   (mob-effect-p mob +mob-effect-climbing-mode+)
                   (or (= (- cz dz) 0)
                       (and (/= (- cz dz) 0)
                            (= nx cx)
                            (= ny cy))
                       )
                   (check-move-along-z cx cy cz nx ny dz)
                   (funcall #'(lambda ()
                                (let ((result nil))
                                  (check-surroundings nx ny nil #'(lambda (dx dy)
                                                                    (when (and (not (get-terrain-type-trait (get-terrain-* (level *world*) dx dy dz) +terrain-trait-not-climable+))
                                                                               (or (get-terrain-type-trait (get-terrain-* (level *world*) dx dy dz) +terrain-trait-opaque-floor+)
                                                                                   (get-terrain-type-trait (get-terrain-* (level *world*) dx dy dz) +terrain-trait-blocks-move+)))
                                                                      (setf result t))))
                                  result))))
          (setf move-result t))

        ;; you can go anywhere horizontaly or directly up/down if you are flying
        (when (and (not move-result)
                   (mob-effect-p mob +mob-effect-flying+)
                   (or (= (- cz dz) 0)
                       (and (/= (- cz dz) 0)
                            (= nx cx)
                            (= ny cy))
                       )
                   (check-move-along-z cx cy cz nx ny dz)
                   )
          (setf move-result t))

        (when (and (not move-result)
                   (mob-effect-p mob +mob-effect-flying+)
                   (> (map-size mob) 1)
                   (/= (- cz dz) 0)
                   (check-move-along-z nx ny cz nx ny dz)
                   )
          (setf move-result t))

        ;; you can not go directly up if the you are under effect of gravity pull
        (when (and (and (< (- cz dz) 0)
                        (= nx cx)
                        (= ny cy))
                   (mob-effect-p mob +mob-effect-gravity-pull+))
          (setf move-result nil))
        
        (unless move-result
          (return-from check-move-for-ai nil))
        
            ))

    t))

(defun ai-find-move-around (mob tx ty)
  (declare (optimize (speed 3))
           (type fixnum tx ty))
  (let* ((cell-list)
         (map-size (map-size mob))
         (half-size (truncate (1- map-size) 2)))
    (declare (type list cell-list)
             (type fixnum map-size half-size))
    ;; collect all cells that constitute the perimeter of the mob around the target cell
    (loop for off of-type fixnum from (- half-size) to (+ half-size)
          for x of-type fixnum = (+ tx off)
          for y-up of-type fixnum = (- ty half-size)
          for y-down of-type fixnum = (+ ty half-size)
          for y of-type fixnum = (+ ty off)
          for x-up of-type fixnum = (- tx half-size)
          for x-down of-type fixnum = (+ tx half-size)
          do
             (push (cons x y-up) cell-list)
             (push (cons x y-down) cell-list)
             (push (cons x-up y) cell-list)
             (push (cons x-down y) cell-list))

    ;(format t "AI-FIND-MOVE-AROUND: Cell list with duplicates ~A~%" cell-list)
    
    ;; remove all duplicates from the list
    (setf cell-list (remove-duplicates cell-list :test #'(lambda (a b)
                                                           (let ((x1 (car a))
                                                                 (x2 (car b))
                                                                 (y1 (cdr a))
                                                                 (y2 (cdr b)))
                                                             (declare (type fixnum x1 x2 y1 y2))
                                                             (if (and (= x1 x2)
                                                                      (= y1 y2))
                                                               t
                                                               nil)))))

    ;(format t "AI-FIND-MOVE-AROUND: Cell list without duplicates ~A~%" cell-list)
    
    ;; sort them so that the closest to the mob are checked first
    (setf cell-list (stable-sort cell-list #'(lambda (a b)
                                               (if (< (get-distance (x mob) (y mob) (car a) (cdr a))
                                                      (get-distance (x mob) (y mob) (car b) (cdr b)))
                                                 t
                                                 nil))))

    ;;(format t "AI-FIND-MOVE-AROUND: Cell list sorted ~A~%" cell-list)
    
    ;; check each cell for passability
    (loop for (dx . dy) in cell-list
          when (and (level-cells-connected-p (level *world*) dx dy (z mob) (x mob) (y mob) (z mob) map-size (get-mob-move-mode mob))
                    (check-move-for-ai mob dx dy (z mob) dx dy (z mob)))
            do
               ;;(format t "AI-FIND-MOVE-AROUND: Return value ~A~%" (cons dx dy))
               (return-from ai-find-move-around (list dx dy (z mob))))

    ;;(format t "AI-FIND-MOVE-AROUND: Return value ~A~%" nil)
    nil))

(defun ai-mob-flee (mob nearest-enemy)
  (unless nearest-enemy
    (return-from ai-mob-flee nil))
  
  (logger (format nil "AI-FUNCTION: ~A [~A] tries to flee away from ~A [~A].~%" (name mob) (id mob) (name nearest-enemy) (id nearest-enemy)))
  
  (let ((step-x 0) 
        (step-y 0))

    (setf (path mob) nil)
    (setf (path-dst mob) nil)
    (setf step-x (if (> (x nearest-enemy) (x mob)) -1 1))
    (setf step-y (if (> (y nearest-enemy) (y mob)) -1 1))

    (when (and (zerop (random 10))
               (mob-ability-p mob +mob-abil-human+))
      (if (check-mob-visible mob :observer *player* :complete-check t)
        (generate-sound mob (x mob) (y mob) (z mob) 100 #'(lambda (str)
                                                            (format nil "~A cries: \"Help! Help!\"~A. " (capitalize-name (prepend-article +article-the+ (visible-name mob))) str))
                        :force-sound t)
        (generate-sound mob (x mob) (y mob) (z mob) 100 #'(lambda (str)
                                                            (format nil "Somebody cries: \"Help! Help!\"~A. " str))
                      :force-sound t))
      ;(print-visible-message (x mob) (y mob) (z mob) (level *world*) (format nil "~A cries: \"Help! Help!\" " (visible-name mob)))
      )
    
    ;; if can't move away - try any random direction
    (unless (move-mob mob (x-y-into-dir step-x step-y))
      (logger (format nil "AI-FUNCTION: ~A [~A] could not flee. Try to move randomly.~%" (name mob) (id mob)))
      (ai-mob-random-dir mob))
    ))

(defun ai-mob-random-dir (mob)
  (logger (format nil "AI-FUNCTION: ~A [~A] tries to move randomly.~%" (name mob) (id mob)))
  (loop for dir = (+ (random 9) 1)
        until (move-mob mob dir)))

(defmethod ai-function ((mob mob))
  ;(declare (optimize (speed 3)))
  (logger (format nil "~%AI-Function Computer ~A [~A] (~A ~A ~A)~%" (name mob) (id mob) (x mob) (y mob) (z mob)))
  
  ;; skip and invoke the master AI
  (when (master-mob-id mob)
    (logger (format nil "AI-FUNCTION: ~A [~A] is being possessed by ~A [~A], skipping its turn.~%" (name mob) (id mob) (name (get-mob-by-id (master-mob-id mob))) (master-mob-id mob)))
    (make-act mob +normal-ap+)
    (return-from ai-function nil))

  (when (and (path-dst mob)
             (= (x mob) (first (path-dst mob)))
             (= (y mob) (second (path-dst mob)))
             (= (z mob) (third (path-dst mob))))
            (setf (path-dst mob) nil))
  
  ;; skip turn if being ridden
  (when (mounted-by-mob-id mob)
    (logger (format nil "AI-FUNCTION: ~A [~A] is being ridden by ~A [~A], moving according to the direction.~%" (name mob) (id mob) (name (get-mob-by-id (mounted-by-mob-id mob))) (mounted-by-mob-id mob)))
    (move-mob mob (x-y-into-dir 0 0))
    (return-from ai-function nil)
    )
    
  
  (update-visible-mobs mob)
  (update-visible-items mob)

  ;; if the mob is blind - move in random direction
  (when (mob-effect-p mob +mob-effect-blind+)
    (logger (format nil "AI-FUNCTION: ~A [~A] is blind, moving in random direction.~%" (name mob) (id mob)))
    (ai-mob-random-dir mob)
    (setf (path mob) nil)
    (return-from ai-function nil))

  ;; if the mob is confused - 33% chance to move in random direction
  (when (and (mob-effect-p mob +mob-effect-confuse+)
             (zerop (random 2)))
    (logger (format nil "AI-FUNCTION: ~A [~A] is confused, moving in random direction.~%" (name mob) (id mob)))
    (ai-mob-random-dir mob)
    (setf (path mob) nil)
    (return-from ai-function nil))

  ;; if the mob is heavily irradiated - (2% * irradiation power) chance to take no action
  (when (and (mob-effect-p mob +mob-effect-irradiated+)
             (< (random 100) (* 2 (param1 (get-effect-by-id (mob-effect-p mob +mob-effect-irradiated+))))))
    (logger (format nil "AI-FUNCTION: ~A [~A] is irradiated, loses turn.~%" (name mob) (id mob)))
    (print-visible-message (x mob) (y mob) (z mob) (level *world*) 
                           (format nil "~A is sick. " (capitalize-name (prepend-article +article-the+ (name mob)))))
    (move-mob mob 5)
    (setf (path mob) nil)
    (return-from ai-function nil))

  ;; if the mob possesses smb, there is a chance that the slave will revolt and move randomly
  (when (and (slave-mob-id mob)
             (zerop (random (* *possessed-revolt-chance* (mob-ability-p mob +mob-abil-can-possess+)))))
    (logger (format nil "AI-FUNCTION: ~A [~A] is revolting against ~A [~A].~%" (name (get-mob-by-id (slave-mob-id mob))) (slave-mob-id mob) (name mob) (id mob)))
    (when (and (check-mob-visible mob :observer *player*)
               (or (mob-effect-p mob +mob-effect-reveal-true-form+)
                   (get-faction-relation (faction mob) (faction *player*))))
      (print-visible-message (x mob) (y mob) (z mob) (level *world*) 
                             (format nil "~A revolts against ~A. " (capitalize-name (prepend-article +article-the+ (name (get-mob-by-id (slave-mob-id mob))))) (prepend-article +article-the+ (name mob)))))
    (setf (path mob) nil)
    (ai-mob-random-dir mob)
    (return-from ai-function nil)
    )
  
  ;; calculate a list of hostile & allied mobs
  (let ((hostile-mobs nil)
        (allied-mobs nil)
        (nearest-enemy nil)
        (nearest-ally nil)
        (nearest-target nil))
    (loop 
      for mob-id of-type fixnum in (visible-mobs mob)
      with vis-mob-type = nil
      do
         
         ;; inspect a mob appearance
         (setf vis-mob-type (get-mob-type-by-id (face-mob-type-id (get-mob-by-id mob-id))))
         ;; however is you are of the same faction, you know who is who
         (when (= (faction mob) (faction (get-mob-by-id mob-id)))
           (setf vis-mob-type (get-mob-type-by-id (mob-type (get-mob-by-id mob-id)))))
                  
         (if (or (get-faction-relation (faction mob) (faction vis-mob-type))
                 (and (mounted-by-mob-id (get-mob-by-id mob-id))
                      (get-faction-relation (faction mob) (faction (get-mob-by-id (mounted-by-mob-id (get-mob-by-id mob-id)))))))
           (progn
             (pushnew mob-id allied-mobs)
             ;; find the nearest allied mob
             (unless nearest-ally
               (setf nearest-ally (get-mob-by-id mob-id)))
             (when (< (get-distance (x (get-mob-by-id mob-id)) (y (get-mob-by-id mob-id)) (x mob) (y mob))
                      (get-distance (x nearest-ally) (y nearest-ally) (x mob) (y mob)))
               (setf nearest-ally (get-mob-by-id mob-id)))
             )
           (progn
             (pushnew mob-id hostile-mobs)
             
             ;; find the nearest hostile mob
             (unless nearest-enemy
               (setf nearest-enemy (get-mob-by-id mob-id)))
             (when (< (get-distance (x (get-mob-by-id mob-id)) (y (get-mob-by-id mob-id)) (x mob) (y mob))
                      (get-distance (x nearest-enemy) (y nearest-enemy) (x mob) (y mob)))
               (setf nearest-enemy (get-mob-by-id mob-id)))
             )))

    ;; by default, the target is the enemy
    (setf nearest-target nearest-enemy)
    
    ;; if the mob is coward, move away from the nearest enemy
    (when (and nearest-enemy (mob-ai-coward-p mob))
      (logger (format nil "AI-FUNCTION: ~A [~A] is a coward with an enemy ~A [~A] in sight.~%" (name mob) (id mob) (name nearest-target) (id nearest-target)))
      (ai-mob-flee mob nearest-enemy)      
      (return-from ai-function))

    ;; if the mob is feared, move away from the nearest enemy
    (when (and nearest-enemy (mob-effect-p mob +mob-effect-fear+))
      (logger (format nil "AI-FUNCTION: ~A [~A] is in fear with an enemy ~A [~A] in sight.~%" (name mob) (id mob) (name nearest-target) (id nearest-target)))
      (ai-mob-flee mob nearest-enemy)      
      (return-from ai-function))
    
     ;; if the mob is a split soul, move away from the nearest enemy (without a random action)
    (when (and nearest-enemy (mob-ai-split-soul-p mob))
      (logger (format nil "AI-FUNCTION: ~A [~A] is trying to move away from the enemy ~A [~A] in sight.~%" (name mob) (id mob) (name nearest-target) (id nearest-target)))

      (let ((farthest-tile nil))
        (check-surroundings (x mob) (y mob) nil #'(lambda (dx dy)
                                                        (let ((terrain (get-terrain-* (level *world*) dx dy (z mob))))
                                                          (when (and terrain
                                                                     (or (get-terrain-type-trait terrain +terrain-trait-opaque-floor+)
                                                                         (get-terrain-type-trait terrain +terrain-trait-water+))
                                                                     (not (get-terrain-type-trait terrain +terrain-trait-blocks-move+))
                                                                     (not (get-mob-* (level *world*) dx dy (z mob)))
                                                                     nearest-enemy)
                                                            (unless farthest-tile
                                                              (setf farthest-tile (list dx dy (z mob))))
                                                            (when (> (get-distance dx dy (x nearest-enemy) (y nearest-enemy))
                                                                     (get-distance (first farthest-tile) (second farthest-tile) (x nearest-enemy) (y nearest-enemy)))
                                                              (setf farthest-tile (list dx dy (z mob))))))))
        (if farthest-tile
          (setf (path-dst mob) farthest-tile nearest-target nil)
          (setf (path-dst mob) (list (x mob) (y mob) (z mob)) nearest-target nil))
        ))
      

    
      
    ;; if the mob has horde behavior, compare relative strengths of allies to relative strength of enemies
    ;; if less - flee
    (when (mob-ai-horde-p mob)
      (let ((ally-str (strength mob))
            (enemy-str 0))
        (declare (type fixnum ally-str enemy-str))
        (dolist (ally-id allied-mobs)
          (declare (type fixnum ally-id))
          (incf ally-str (strength (get-mob-by-id ally-id))))
        (dolist (enemy-id hostile-mobs)
          (incf enemy-str (strength (get-mob-type-by-id (face-mob-type-id (get-mob-by-id enemy-id))))))
      
        (logger (format nil "AI-FUNCTION: ~A [~A] has horde behavior. Ally vs. Enemy strength is ~A vs ~A.~%" (name mob) (id mob) ally-str enemy-str))

        (when (< ally-str enemy-str)
          ;; allied strength is less - flee
          (ai-mob-flee mob nearest-enemy)
          (return-from ai-function)))
      )
    
    ;; if the mob wants to give blessings, find the nearest unblessed ally
    ;; if it is closer than the enemy, go to it
    (when (mob-ai-wants-bless-p mob)
      (let ((nearest-ally nil))
        (loop 
          for mob-id in allied-mobs
          with vis-mob-type = nil
          do
             (setf vis-mob-type (get-mob-type-by-id (face-mob-type-id (get-mob-by-id mob-id))))
              ;; when you are of the same faction, you know who is who
             (when (= (faction mob) (faction (get-mob-by-id mob-id)))
               (setf vis-mob-type (get-mob-type-by-id (mob-type (get-mob-by-id mob-id)))))
             
             ;; find the nearest allied unblessed mob mob
             (when (and (mob-ability-p vis-mob-type +mob-abil-can-be-blessed+)
                        (not (mob-effect-p (get-mob-by-id mob-id) +mob-effect-blessed+)))
               (unless nearest-ally
                 (setf nearest-ally (get-mob-by-id mob-id)))
               (when (< (get-distance (x (get-mob-by-id mob-id)) (y (get-mob-by-id mob-id)) (x mob) (y mob))
                        (get-distance (x nearest-ally) (y nearest-ally) (x mob) (y mob)))
                 (setf nearest-ally (get-mob-by-id mob-id))))
          ) 
        (logger (format nil "AI-FUNCTION: ~A [~A] wants to give blessings. Nearest unblessed ally ~A [~A]~%" (name mob) (id mob) (if nearest-ally (name nearest-ally) nil) (if nearest-ally (id nearest-ally) nil)))
        (when (or (and nearest-ally
                       (not nearest-enemy))
                  (and nearest-ally
                       nearest-enemy
                       (< (get-distance (x mob) (y mob) (x nearest-ally) (y nearest-ally))
                          (get-distance (x mob) (y mob) (x nearest-enemy) (y nearest-enemy)))))
          (logger (format nil "AI-FUNCTION: ~A [~A] changed target ~A [~A].~%" (name mob) (id mob) (name nearest-ally) (id nearest-ally)))
          (setf nearest-target nearest-ally))
        ))

    ;; if the mob wants to stop when enemy is in sight, set target to nil
    (when (mob-ai-stop-p mob)
      (when nearest-enemy
        (logger (format nil "AI-FUNCTION: ~A [~A] stop when seeing ~A [~A].~%" (name mob) (id mob) (name nearest-enemy) (id nearest-enemy)))
        (setf nearest-target nil)
        ))

    ;; if the mob is cautious and the nearest enemy's strength is higher than the mobs - set nearest enemy to nil
    (when (and (mob-ai-cautious-p mob)
               nearest-enemy
               (> (strength nearest-enemy) (strength mob)))
      (logger (format nil "AI-FUNCTION: ~A [~A] is too cautious to attack ~A [~A] because STR ~A vs ~A.~%" (name mob) (id mob) (name nearest-enemy) (id nearest-enemy) (strength mob) (strength nearest-enemy)))
      (setf nearest-target nil)
      (setf nearest-enemy nil))

    ;; if the mob is a trinity mimic, assign the first one as a leader and make all others in the group follow it
    (when (mob-ai-trinity-mimic-p mob)
      (setf (order mob) nil)
      (loop for mimic-id in (mimic-id-list mob)
            for mimic = (get-mob-by-id mimic-id)
            when (and (not (eq mimic mob))
                      (not (check-dead mimic))
                      (not (is-merged mimic)))
              do
                 (setf (order mob) (list +mob-order-follow+ mimic-id))
                 (loop-finish)))
    
    ;; invoke abilities if any
    (let ((ability-list) (r 0))
      (declare (type fixnum r)
               (type list ability-list))
               
      ;; find all applicable abilities
      (setf ability-list (loop for ability-id being the hash-key in (abilities mob)
                               for ability = (get-ability-type-by-id ability-id)
                               for func of-type function = (on-check-ai ability)
                               when (and func
                                         (funcall func ability mob nearest-enemy nearest-ally))
                                 collect ability))

      
      ;; randomly choose one of them and invoke it
      (when ability-list
        (setf r (random (length ability-list)))
        (let ((ai-invoke-func (on-invoke-ai (nth r ability-list))))
          (declare (type function ai-invoke-func))
          (logger (format nil "AI-FUNCTION: ~A [~A] decides to invoke ability ~A~%" (name mob) (id mob) (name (nth r ability-list))))
          (funcall ai-invoke-func (nth r ability-list) mob nearest-enemy nearest-ally))
        (return-from ai-function)
        )
      )

    ;; use an item if any
    (let ((item-list) (r 0))
      (declare (type fixnum r)
               (type list item-list))
               
      ;; find all applicable items
      (setf item-list (loop for item-id in (inv mob)
                            for item = (get-item-by-id item-id)
                            for ai-func of-type function = (on-check-ai item)
                            for use-func of-type function = (on-use item) 
                            when (and use-func
                                      ai-func
                                      (funcall ai-func mob item nearest-enemy nearest-ally))
                              collect item))

      
      ;; randomly choose one of them and invoke it
      (when item-list
        (setf r (random (length item-list)))
        (logger (format nil "AI-FUNCTION: ~A [~A] decides to use item ~A [~A]~%" (name mob) (id mob) (name (nth r item-list)) (id (nth r item-list))))
        (mob-use-item mob (nth r item-list))
        (return-from ai-function)
        )
      )
    
    ;; engage in ranged combat
    ;; if no bullets in magazine - reload
    (when (and (is-weapon-ranged mob)
               (not (mob-can-shoot mob)))
      (mob-reload-ranged-weapon mob)
      (return-from ai-function))

    ;; if can shoot and there is an enemy in sight - shoot it
    (when (and (is-weapon-ranged mob)
               (mob-can-shoot mob)
               nearest-enemy)
      (let ((tx 0) (ty 0) (tz 0)
            (ex (x nearest-enemy)) (ey (y nearest-enemy)) (ez (z nearest-enemy)))
        (declare (type fixnum tx ty tz ex ey ez))
        (line-of-sight (x mob) (y mob) (z mob) (x nearest-enemy) (y nearest-enemy) (z nearest-enemy) #'(lambda (dx dy dz prev-cell)
                                                                               (declare (type fixnum dx dy dz))
                                                                               (let ((exit-result t))
                                                                                 (block nil
                                                                                   (setf tx dx ty dy tz dz)

                                                                                   (unless (check-LOS-propagate dx dy dz prev-cell :check-projectile t)
                                                                                     (setf exit-result 'exit)
                                                                                     (return))
                                                                                   
                                                                                   )
                                                                                 exit-result)))
        (when (and (= tx ex)
                   (= ty ey)
                   (= tz ez))
          (mob-shoot-target mob nearest-enemy)
          (return-from ai-function))))

    ;; if no enemy in sight and the magazine is not full - reload it
    (when (and (is-weapon-ranged mob)
               (not nearest-enemy)
               (< (get-ranged-weapon-charges mob) (get-ranged-weapon-max-charges mob)))
      (mob-reload-ranged-weapon mob)
      (return-from ai-function))

    ;; follow the leader
    (when (and (order mob)
               (= (first (order mob)) +mob-order-follow+))
      ;; if the leader is nearby, plot the path to it
      (let ((leader (get-mob-by-id (second (order mob)))))
        (if (check-dead leader)
          (progn
            (setf (order mob) nil))
          (progn
            (when (and (< (get-distance (x mob) (y mob) (x leader) (y leader)) 8)
                       (> (get-distance (x mob) (y mob) (x leader) (y leader)) 2))
              (logger (format nil "AI-FUNCTION: Mob (~A, ~A, ~A) wants to follow the leader to (~A, ~A, ~A)~%" (x mob) (y mob) (z mob) (x leader) (y leader) (z leader)))
              (setf nearest-target leader))))
        ))
    
    ;; got to the nearest target
    (when nearest-target
      (logger (format nil "AI-FUNCTION: Target found ~A [~A] (~A ~A ~A)~%" (name nearest-target) (id nearest-target) (x nearest-target) (y nearest-target) (z nearest-target)))
      (cond
        ((level-cells-connected-p (level *world*) (x mob) (y mob) (z mob) (x nearest-target) (y nearest-target) (z nearest-target) (if (riding-mob-id mob)
                                                                                                                                     (map-size (get-mob-by-id (riding-mob-id mob)))
                                                                                                                                     (map-size mob))
                                  (get-mob-move-mode mob))
         (setf (path-dst mob) (list (x nearest-target) (y nearest-target) (z nearest-target)))
         (setf (path mob) nil))
        ((and (> (map-size mob) 1)
              (ai-find-move-around mob (x nearest-target) (y nearest-target)))
         (setf (path-dst mob) (ai-find-move-around mob (x nearest-target) (y nearest-target)))
         (setf (path mob) nil))))

    ;; if the mob is curious and it has nothing to do - move to the nearest sound, if any
    (when (and (mob-ai-curious-p mob)
               (null nearest-target)
               (not (null (heard-sounds mob))))
      (setf (heard-sounds mob) (stable-sort (heard-sounds mob) #'(lambda (a b)
                                                                (if (< (get-distance-3d (x mob) (y mob) (z mob) (sound-x a) (sound-y a) (sound-z a))
                                                                       (get-distance-3d (x mob) (y mob) (z mob) (sound-x b) (sound-y b) (sound-z b)))
                                                                  t
                                                                  nil))))
      ;(format t "SOUNDS ~A~%" (heard-sounds mob))
      (loop for sound in (heard-sounds mob)
            when (level-cells-connected-p (level *world*) (x mob) (y mob) (z mob) (sound-x sound) (sound-y sound) (sound-z sound) (if (riding-mob-id mob)
                                                                                                                                    (map-size (get-mob-by-id (riding-mob-id mob)))
                                                                                                                                    (map-size mob))
                                          (get-mob-move-mode mob))
              do
                 (setf (path-dst mob) (list (sound-x sound) (sound-y sound) (sound-z sound)))
                 (setf (path mob) nil)
                 (loop-finish)
            when (and (> (map-size mob) 1)
                      (ai-find-move-around mob (sound-x sound) (sound-y sound)))
              do
                 (setf (path-dst mob) (ai-find-move-around mob (sound-x sound) (sound-y sound)))
                 (setf (path mob) nil)
                 (loop-finish)
            finally (logger (format nil "AI-FUNCTION: Mob (~A ~A ~A) wants to investigate sound at (~A, ~A, ~A)~%" (x mob) (y mob) (z mob) (first (path-dst mob)) (second (path-dst mob)) (third (path-dst mob))))))

    
    
    ;; when mob is kleptomaniac and has no target
    (when (and (mob-ai-kleptomaniac-p mob)
               (null nearest-target)
               (visible-items mob))
      ;; if standing on an item of value > 0 - pick it up
      (loop for item-id in (get-items-* (level *world*) (x mob) (y mob) (z mob))
            for item = (get-item-by-id item-id)
            when (not (zerop (value item)))
              do
                 (mob-pick-item mob item)
                 (return-from ai-function))

      ;; find all visible items with value > 0
      ;; go to the nearest such item
      (let ((visible-items (copy-list (visible-items mob))))
        (setf visible-items (remove-if #'(lambda (item)
                                           (zerop (value item)))
                                       visible-items
                                       :key #'get-item-by-id))
        
        (setf visible-items (stable-sort visible-items #'(lambda (a b)
                                                         (if (< (get-distance-3d (x mob) (y mob) (z mob) (x a) (y a) (z a))
                                                                (get-distance-3d (x mob) (y mob) (z mob) (x b) (y b) (z b)))
                                                           t
                                                           nil))
                                         :key #'get-item-by-id))

        (loop for item-id in visible-items
              for item = (get-item-by-id item-id)
              when (level-cells-connected-p (level *world*) (x mob) (y mob) (z mob) (x item) (y item) (z item) (if (riding-mob-id mob)
                                                                                                                 (map-size (get-mob-by-id (riding-mob-id mob)))
                                                                                                                 (map-size mob))
                                            (get-mob-move-mode mob))
                do
                   (setf (path-dst mob) (list (x item) (y item) (z item)))
                   (setf (path mob) nil)
                   (loop-finish)
              when (and (> (map-size mob) 1)
                        (ai-find-move-around mob (x item) (y item)))
                do
                   (setf (path-dst mob) (ai-find-move-around mob (x item) (y item)))
                   (setf (path mob) nil)
                   (loop-finish)
              finally
                 (when item
                   (logger (format nil "AI-FUNCTION: Mob (~A ~A ~A) wants to get item ~A [~A] at (~A, ~A, ~A)~%" (x mob) (y mob) (z mob) (name item) (id item) (first (path-dst mob)) (second (path-dst mob)) (third (path-dst mob))))))
        ))

    
    
    ;; move to some random passable terrain
    (unless (path-dst mob)
      (let ((rx (- (+ 10 (x mob))
                   (1+ (random 20)))) 
            (ry (- (+ 10 (y mob))
                   (1+ (random 20))))
            (rz (- (+ 5 (z mob))
                   (1+ (random 10))))
            )
        (declare (type fixnum rx ry rz))
        (logger (format nil "AI-FUNCTION: Mob (~A, ~A, ~A) wants to go to a random nearby place~%" (x mob) (y mob) (z mob)))
        (logger (format nil "AI-FUNCTION: TERRAIN ~A~%" (get-terrain-* (level *world*) (x mob) (y mob) (z mob))))
        (loop while (or (< rx 0) (< ry 0) (< rz 0) (>= rx (array-dimension (terrain (level *world*)) 0)) (>= ry (array-dimension (terrain (level *world*)) 1)) (>= rz (array-dimension (terrain (level *world*)) 2))
                        (get-terrain-type-trait (get-terrain-* (level *world*) rx ry rz) +terrain-trait-blocks-move+)
                        (and (not (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-water+))
                             (not (get-terrain-type-trait (get-terrain-* (level *world*) rx ry rz) +terrain-trait-opaque-floor+))
                             (not (mob-effect-p mob +mob-effect-flying+)))
                        
                        ;(and (get-mob-* (level *world*) rx ry rz)
                        ;     (not (eq (get-mob-* (level *world*) rx ry rz) mob)))
                        (not (level-cells-connected-p (level *world*) (x mob) (y mob) (z mob) rx ry rz (if (riding-mob-id mob)
                                                                                                         (map-size (get-mob-by-id (riding-mob-id mob)))
                                                                                                         (map-size mob))
                                                      (get-mob-move-mode mob)))
                        )
              do
                 (logger (format nil "AI-FUNCTION: R (~A ~A ~A)~%TERRAIN = ~A, MOB ~A [~A], CONNECTED ~A~%"
                                 rx ry rz
                                 (get-terrain-* (level *world*) rx ry rz)
                                 (get-mob-* (level *world*) rx ry rz) (if (get-mob-* (level *world*) rx ry rz)
                                                                        (id (get-mob-* (level *world*) rx ry rz))
                                                                        nil)
                                 (level-cells-connected-p (level *world*) (x mob) (y mob) (z mob) rx ry rz (if (riding-mob-id mob)
                                                                                                             (map-size (get-mob-by-id (riding-mob-id mob)))
                                                                                                             (map-size mob))
                                                          (get-mob-move-mode mob))))
                 (setf rx (- (+ 10 (x mob))
                             (1+ (random 20))))
                 (setf ry (- (+ 10 (y mob))
                             (1+ (random 20))))
                 (setf rz (- (+ 5 (z mob))
                             (1+ (random 10))))
              (logger (format nil "AI-FUNCTION: NEW R (~A ~A ~A)~%" rx ry rz)))
        (setf (path-dst mob) (list rx ry rz))
        (logger (format nil "AI-FUNCTION: Mob's destination is randomly set to (~A, ~A, ~A)~%" (first (path-dst mob)) (second (path-dst mob)) (third (path-dst mob))))))
    
    ;; calculate path to the destination
    (when (and (path-dst mob)
               (not (mob-ai-simple-pathfinding-p mob))
               (or (null (path mob))
                   (mob-ability-p mob +mob-abil-momentum+)))
      (let ((path nil))
        (when (level-cells-connected-p (level *world*) (x mob) (y mob) (z mob) (first (path-dst mob)) (second (path-dst mob)) (third (path-dst mob)) (if (riding-mob-id mob)
                                                                                                                                                       (map-size (get-mob-by-id (riding-mob-id mob)))
                                                                                                                                                       (map-size mob))
                                       (get-mob-move-mode mob))
          (logger (format nil "AI-FUNCTION: Mob (~A, ~A, ~A) wants to go to (~A, ~A, ~A)~%" (x mob) (y mob) (z mob) (first (path-dst mob)) (second (path-dst mob)) (third (path-dst mob))))
          (setf path (a-star (list (x mob) (y mob) (z mob)) (list (first (path-dst mob)) (second (path-dst mob)) (third (path-dst mob))) 
                               #'(lambda (dx dy dz cx cy cz) 
                                   ;; checking for impassable objects
                                   (check-move-for-ai mob dx dy dz cx cy cz :final-dst (path-dst mob))
                                   )
                               #'(lambda (dx dy dz)
                                   ;; a magic hack here - as values of more than 10 give an unexplainable slowdown
                                   (* (get-terrain-type-trait (get-terrain-* (level *world*) dx dy dz) +terrain-trait-move-cost-factor+)
                                      (move-spd (get-mob-type-by-id (mob-type mob)))
                                      1/10))))
                    
          (pop path)
          (logger (format nil "AI-FUNCTION: Set mob path - ~A~%" path))
          (setf (path mob) path)
          )))
    
    ;; if the mob has its path set - move along it
    (when (path mob)

        (let ((step) (step-x) (step-y) (step-z) (move-result nil))
        
          (logger (format nil "AI-FUNCTION: Move mob along the path - ~A~%" (path mob)))
          (setf step (pop (path mob)))
          
          ;; if there is suddenly an obstacle, make the path recalculation
          (setf step-x (- (first step) (x mob)))
          (setf step-y (- (second step) (y mob)))
          (setf step-z (- (third step) (z mob)))
          
          (unless (check-move-on-level mob (first step) (second step) (third step))
            (logger (format nil "AI-FUNCTION: Can't move to target - (~A ~A ~A)~%" (first step) (second step) (third step)))
            (setf (path mob) nil)
            (setf (path-dst mob) nil)
            (return-from ai-function))
          
          (unless (x-y-into-dir step-x step-y)
            (logger (format nil "AI-FUNCTION: Wrong direction supplied (~A ~A)~%" (first step) (second step)))
            (setf (path mob) nil)
            (setf (path-dst mob) nil)
            (return-from ai-function))
          
          (setf move-result (move-mob mob (x-y-into-dir step-x step-y) :dir-z step-z))

          (logger (format nil "AI-FUNCTION: PATH-DST ~A, MOB (~A ~A ~A), MOVE-RESULT ~A~%" (path-dst mob) (x mob) (y mob) (z mob) move-result))
          (if move-result
            (progn
              (when (and (path-dst mob)
                         (= (x mob) (first (path-dst mob)))
                         (= (y mob) (second (path-dst mob)))
                         (= (z mob) (third (path-dst mob))))
                (setf (path-dst mob) nil))
              (return-from ai-function))
            (progn
              (logger (format nil "AI-FUNCTION: Move failed ~A~%" move-result))
              (setf (path-dst mob) nil)
              (setf (path mob) nil)))
          
          ))
    
    ;; if there are no hostile mobs move randomly
    ;; pester the AI until it makes some meaningful action
    (ai-mob-random-dir mob)
    )
  )
  

(defmethod ai-function ((player player))
  (logger (format nil "~%AI-FUnction Player~%"))
  ;(logger (format nil "~%TIME-ELAPSED BEFORE: ~A~%" (- (get-internal-real-time) *time-at-end-of-player-turn*)))

  
  (format t "~%TIME-ELAPSED BEFORE: ~A~%" (- (get-internal-real-time) *time-at-end-of-player-turn*))

  ;; this should be done in this order for the lit-unlit tiles to be displayed properly
  ;; because update-visible-area actually sets the glyphs and colors of the player screen
  ;; while update-visible-mobs prepares the lit-unlit status of the tiles
  (update-visible-mobs player)
  (update-visible-area (level *world*) (x player) (y player) (z player))

  (format t "TIME-ELAPSED AFTER: ~A~%" (- (get-internal-real-time) *time-at-end-of-player-turn*))
  
  ;; find the nearest enemy
  (when (mob-ability-p *player* +mob-abil-detect-good+)
    (sense-good))
  (when (mob-ability-p *player* +mob-abil-detect-evil+)
    (sense-evil))

  ;; print out the items on the player's tile
  (loop for item-id in (get-items-* (level *world*) (x *player*) (y *player*) (z *player*))
        for item = (get-item-by-id item-id)
        with n = 0
        do
           (when (zerop n)
             (add-message "You see "))
           (when (not (zerop n))
             (add-message ", "))
           (add-message (format nil "~A" (prepend-article +article-a+ (visible-name item))))
           (incf n)
        finally (when (not (zerop n))
                  (add-message (format nil ".~%"))))
  
  (make-output *current-window*) 

  ;; if player is fearing somebody & there is an enemy nearby
  ;; wait for a meaningful action and move randomly instead
  (when (mob-effect-p *player* +mob-effect-fear+)
    (logger (format nil "AI-FUNCTION: ~A [~A] is under effects of fear.~%" (name player) (id player)))
    (let ((nearest-enemy nil))
      (loop for mob-id of-type fixnum in (visible-mobs *player*)
            for mob = (get-mob-by-id mob-id)
            with vis-mob-type = nil
            do
               ;; inspect a mob appearance
               (setf vis-mob-type (get-mob-type-by-id (face-mob-type-id mob)))
               ;; however is you are of the same faction, you know who is who
               (when (= (faction *player*) (faction mob))
                 (setf vis-mob-type (get-mob-type-by-id (mob-type mob))))
                  
               (when (not (get-faction-relation (faction *player*) (faction vis-mob-type)))
                 ;; find the nearest hostile mob
                 (unless nearest-enemy
                   (setf nearest-enemy mob))
                 (when (< (get-distance (x mob) (y mob) (x *player*) (y *player*))
                          (get-distance (x nearest-enemy) (y nearest-enemy) (x *player*) (y *player*)))
                   (setf nearest-enemy mob))
                 ))
      
      (when nearest-enemy
        (logger (format nil "AI-FUNCTION: ~A [~A] fears ~A [~A].~%" (name player) (id player) (name nearest-enemy) (id nearest-enemy)))
        (setf (can-move-if-possessed player) t)
        (loop while (can-move-if-possessed player) do
          (get-input-player))
        (ai-mob-flee *player* nearest-enemy)
        (return-from ai-function nil))))

  ;; if the player is confused and the RNG is right
  ;; wait for a meaningful action and move randomly instead
  (when (and (mob-effect-p player +mob-effect-confuse+)
             (zerop (random 2)))
    (logger (format nil "AI-FUNCTION: ~A [~A] is under effects of confusion.~%" (name player) (id player)))
    (setf (can-move-if-possessed player) t)
    (loop while (can-move-if-possessed player) do
      (get-input-player))
    (print-visible-message (x player) (y player) (z player) (level *world*) 
                           (format nil "~A is confused. " (capitalize-name (name player))))
    (ai-mob-random-dir *player*)
    (return-from ai-function nil))

  ;; if the player is irradiated and the RNG is right
  ;; wait for a meaningful action and wait a turn instead
  (when (and (mob-effect-p player +mob-effect-irradiated+)
             (< (random 100) (* 2 (param1 (get-effect-by-id (mob-effect-p player +mob-effect-irradiated+))))))
    (logger (format nil "AI-FUNCTION: ~A [~A] is under effects of irradiation.~%" (name player) (id player)))
    (setf (can-move-if-possessed player) t)
    (loop while (can-move-if-possessed player) do
      (get-input-player))
    (print-visible-message (x player) (y player) (z player) (level *world*) 
                           (format nil "~A feels sick. " (capitalize-name (name player))))
    (move-mob player 5)
    (return-from ai-function nil))
  
  ;; if possessed & unable to revolt - wait till the player makes a meaningful action
  ;; then skip and invoke the master AI
  (logger (format nil "AI-FUNCTION: MASTER ID ~A, SLAVE ID ~A~%" (master-mob-id player) (slave-mob-id player)))
  (when (master-mob-id player)
    (logger (format nil "AI-FUNCTION: ~A [~A] is being possessed by ~A [~A].~%" (name player) (id player) (name (get-mob-by-id (master-mob-id player))) (master-mob-id player)))
    
    (setf (x player) (x (get-mob-by-id (master-mob-id player))) (y player) (y (get-mob-by-id (master-mob-id player))) (z player) (z (get-mob-by-id (master-mob-id player))))
    
    (setf (can-move-if-possessed player) t)
    (loop while (can-move-if-possessed player) do
      (get-input-player))
        
    (if (zerop (random (* *possessed-revolt-chance* (mob-ability-p (get-mob-by-id (master-mob-id player)) +mob-abil-can-possess+))))
      (progn
        (logger (format nil "AI-FUNCTION: ~A [~A] revolts against ~A [~A].~%" (name player) (id player) (name (get-mob-by-id (master-mob-id player))) (master-mob-id player)))
        
        (print-visible-message (x player) (y player) (z player) (level *world*) 
                               (format nil "~A revolts against ~A. " (capitalize-name (name player)) (name (get-mob-by-id (master-mob-id player))) ))
        (ai-mob-random-dir (get-mob-by-id (master-mob-id player)))
        (setf (x player) (x (get-mob-by-id (master-mob-id player))) (y player) (y (get-mob-by-id (master-mob-id player))) (z player) (z (get-mob-by-id (master-mob-id player))))
        (setf (path (get-mob-by-id (master-mob-id player))) nil)
        (return-from ai-function nil)
        )
      (progn
        (logger (format nil "AI-FUNCTION: ~A [~A] was unable to revolt against ~A [~A].~%" (name player) (id player) (name (get-mob-by-id (master-mob-id player))) (master-mob-id player)))
                
        (ai-function (get-mob-by-id (master-mob-id player)))
        
        (when (master-mob-id player)
          (setf (x player) (x (get-mob-by-id (master-mob-id player))) (y player) (y (get-mob-by-id (master-mob-id player))) (z player) (z (get-mob-by-id (master-mob-id player)))))
        
        (make-act player +normal-ap+)
        (return-from ai-function nil)))
    )
  
  ;; if player possesses somebody & the slave revolts
  ;; wait for a meaningful action and move randomly instead 
  (when (slave-mob-id player)
    (when (zerop (random (* *possessed-revolt-chance* (mob-ability-p player +mob-abil-can-possess+))))
      (logger (format nil "AI-FUNCTION: ~A [~A] possesses ~A [~A], but the slave revolts.~%" (name player) (id player) (name (get-mob-by-id (slave-mob-id player))) (slave-mob-id player)))
      (setf (can-move-if-possessed player) t)
      (loop while (can-move-if-possessed player) do
        (get-input-player))
      
      (print-visible-message (x player) (y player) (z player) (level *world*) 
                             (format nil "~A revolts against ~A. " (capitalize-name (name (get-mob-by-id (slave-mob-id player)))) (name player)))
      (ai-mob-random-dir player)
      (return-from ai-function nil)
    ))
  
  ;; player is able to move freely
  ;; pester the player until it makes some meaningful action that can trigger the event chain
  (loop until (made-turn player) do
    (setf (can-move-if-possessed player) nil)
    (get-input-player))
  (setf *time-at-end-of-player-turn* (get-internal-real-time)))


(defun thread-path-loop (stream)
  (loop while t do
    (bt:with-lock-held ((path-lock *world*))      
      (if (and (< (cur-mob-path *world*) (length (mob-id-list (level *world*)))) (not (made-turn *player*)))
        (progn
          (when (and (not (eq *player* (get-mob-by-id (cur-mob-path *world*))))
                     (not (dead= (get-mob-by-id (cur-mob-path *world*))))
                     (not (path (get-mob-by-id (cur-mob-path *world*)))))
            (logger (format nil "~%THREAD: Mob ~A [~A] calculates paths~%" (name (get-mob-by-id (cur-mob-path *world*))) (id (get-mob-by-id (cur-mob-path *world*)))) stream)
            (let* ((mob (get-mob-by-id (cur-mob-path *world*)))
                   (rx (- (+ 10 (x mob))
                          (1+ (random 20)))) 
                   (ry (- (+ 10 (y mob))
                          (1+ (random 20))))
                   (rz (- (+ 5 (z mob))
                          (1+ (random 10))))
                   (path nil)
                   )
              (declare (type fixnum rx ry))

              ;; if the mob destination is not set, choose a random destination
              (unless (path-dst mob)
                (loop while (or (< rx 0) (< ry 0) (< rz 0) (>= rx (array-dimension (terrain (level *world*)) 0)) (>= ry (array-dimension (terrain (level *world*)) 1)) (>= rz (array-dimension (terrain (level *world*)) 2))
                                (get-terrain-type-trait (get-terrain-* (level *world*) rx ry rz) +terrain-trait-blocks-move+)
                                ;(not (get-terrain-type-trait (get-terrain-* (level *world*) rx ry rz) +terrain-trait-opaque-floor+))
                                (and (not (get-terrain-type-trait (get-terrain-* (level *world*) (x mob) (y mob) (z mob)) +terrain-trait-water+))
                                     (not (get-terrain-type-trait (get-terrain-* (level *world*) rx ry rz) +terrain-trait-opaque-floor+))
                                     (not (mob-effect-p mob +mob-effect-flying+)))
                                (not (level-cells-connected-p (level *world*) (x mob) (y mob) (z mob) rx ry rz (if (riding-mob-id mob)
                                                                                                                 (map-size (get-mob-by-id (riding-mob-id mob)))
                                                                                                                 (map-size mob))
                                                              (get-mob-move-mode mob)))
                                )
                      do
                         (setf rx (- (+ 10 (x mob))
                                     (1+ (random 20))))
                         (setf ry (- (+ 10 (y mob))
                                     (1+ (random 20))))
                         (setf rz (- (+ 5 (z mob))
                                     (1+ (random 10)))))
                (setf (path-dst mob) (list rx ry rz)))

              (when (level-cells-connected-p (level *world*) (x mob) (y mob) (z mob) (first (path-dst mob)) (second (path-dst mob)) (third (path-dst mob)) (if (riding-mob-id mob)
                                                                                                                                                             (map-size (get-mob-by-id (riding-mob-id mob)))
                                                                                                                                                             (map-size mob))
                                             (get-mob-move-mode mob))
                (logger (format nil "THREAD: Mob (~A, ~A, ~A) wants to go to (~A, ~A, ~A)~%" (x mob) (y mob) (z mob) (first (path-dst mob)) (second (path-dst mob)) (third (path-dst mob))) stream)
                (setf path (a-star (list (x mob) (y mob) (z mob)) (list (first (path-dst mob)) (second (path-dst mob)) (third (path-dst mob))) 
                                    #'(lambda (dx dy dz cx cy cz) 
                                        ;; checking for impassable objects
                                        (check-move-for-ai mob dx dy dz cx cy cz)
                                        )
                                    #'(lambda (dx dy dz)
                                        ;; a magic hack here - as values of more than 10 give an unexplainable slowdown
                                        (* (get-terrain-type-trait (get-terrain-* (level *world*) dx dy dz) +terrain-trait-move-cost-factor+)
                                           (move-spd (get-mob-type-by-id (mob-type mob)))
                                           1/10))))
                 
                (pop path)
                (logger (format nil "THREAD: Set mob path - ~A~%" path) stream)
                (setf (path mob) path)
                ))
            )
          (incf (cur-mob-path *world*))
          (logger (format nil "THREAD: cur-mob-path - ~A~%" (cur-mob-path *world*)) stream))
        (progn
          (logger (format nil "THREAD: Done calculating paths~%~%") stream)
          (setf (cur-mob-path *world*) (length (mob-id-list (level *world*))))
          (bt:condition-wait (path-cv *world*) (path-lock *world*)))
        
        ))))
