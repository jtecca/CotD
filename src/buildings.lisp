(in-package :cotd)

;;--------------------------------------
;; GENERAL BUILDING TYPES
;;--------------------------------------

(defconstant +building-type-none+ 0)
(defconstant +building-type-house+ 1)
(defconstant +building-type-townhall+ 2)
(defconstant +building-type-park+ 3)
(defconstant +building-type-lake+ 4)
(defconstant +building-type-prison+ 5)
(defconstant +building-type-church+ 6)
(defconstant +building-type-library+ 7)
(defconstant +building-type-warehouse+ 8)
(defconstant +building-type-satanists+ 9)
(defconstant +building-type-stables+ 10)
(defconstant +building-type-mansion+ 11)
(defconstant +building-type-bank+ 12)
(defconstant +building-type-graveyard+ 13)

;;--------------------------------------
;; SPECIFIC BUILDING TYPES
;;--------------------------------------
(defconstant +building-city-free+ 0)
(defconstant +building-city-reserved+ 1)
(defconstant +building-city-house-1+ 2)
(defconstant +building-city-house-2+ 3)
(defconstant +building-city-house-3+ 4)
(defconstant +building-city-house-4+ 5)
(defconstant +building-city-townhall-1+ 6)
(defconstant +building-city-park-1+ 7)
(defconstant +building-city-lake-1+ 8)
(defconstant +building-city-park-2+ 9)
(defconstant +building-city-prison-1+ 10)
(defconstant +building-city-church-1+ 11)
(defconstant +building-city-warehouse-1+ 12)
(defconstant +building-city-library-1+ 13)
(defconstant +building-city-park-3+ 14)
(defconstant +building-city-lake-2+ 15)
(defconstant +building-city-park-tiny+ 16)
(defconstant +building-city-townhall-2+ 17)
(defconstant +building-city-townhall-3+ 18)
(defconstant +building-city-townhall-4+ 19)
(defconstant +building-city-satan-lair-1+ 20)
(defconstant +building-city-river+ 21)
(defconstant +building-city-bridge+ 22)
(defconstant +building-city-pier+ 23)
(defconstant +building-city-sea+ 24)
(defconstant +building-city-warehouse-port-1+ 25)
(defconstant +building-city-warehouse-port-2+ 26)
(defconstant +building-city-island-ground-border+ 27)
(defconstant +building-city-barricade-ns+ 28)
(defconstant +building-city-barricade-we+ 29)
(defconstant +building-city-barricade-se+ 30)
(defconstant +building-city-barricade-sw+ 31)
(defconstant +building-city-barricade-nw+ 32)
(defconstant +building-city-barricade-ne+ 33)
(defconstant +building-city-stables-1+ 34)
(defconstant +building-city-mansion-1+ 35)
(defconstant +building-city-mansion-2+ 36)
(defconstant +building-city-park-4+ 37)
(defconstant +building-city-bank-1+ 38)
(defconstant +building-city-graveyard-1+ 39)
(defconstant +building-city-church-2+ 40)

(defparameter *level-grid-size* 5)

(defvar *building-types* (make-hash-table))
(defvar *general-building-types* (make-hash-table))

(defstruct building
  (id)       ;; building id 
  (grid-dim) ;; dimensions on a grid map, type (X . Y)
  (act-dim)  ;; dimensions on an actual map, type (X . Y)
  (func)     ;; function that places the building onto the actual map
  (type +building-type-none+)
  )

(defun get-building-grid-dim (building)
  (values (car (building-grid-dim building)) 
          (cdr (building-grid-dim building))))

(defun get-building-act-dim (building)
  (values (car (building-act-dim building)) 
          (cdr (building-act-dim building))))

(defun set-building-type (building)
  (destructuring-bind (adx . ady) (building-act-dim building)
    (destructuring-bind (gdx . gdy) (building-grid-dim building)
      (when (or (> adx (* gdx *level-grid-size*))
                (> ady (* gdy *level-grid-size*)))
        (error "Grid and actual dimensions do not match!"))))
  (unless (= (building-type building) +building-type-none+)
    (setf (gethash (building-type building) *general-building-types*) t))
  (setf (gethash (building-id building) *building-types*) building))

(defun get-building-type (building-type-id)
  (gethash building-type-id *building-types*))

(defun translate-build-to-template (x y z build-template template-level)
  (loop for y1 from 0 below (length build-template) do
    (loop for c across (nth y1 build-template) 
          and x1 from 0
          for tt = (case c
                     (#\. +terrain-floor-stone+)
                     (#\# +terrain-wall-stone+)
                     (#\T +terrain-tree-birch+)
                     (#\, (if (< (random 100) 20)
                            +terrain-floor-dirt-bright+
                            +terrain-floor-dirt+))
                     (#\_ +terrain-water-liquid+)
                     (#\` +terrain-floor-grass+)
                     (#\- +terrain-wall-window+)
                     (#\h +terrain-floor-chair+)
                     (#\t +terrain-floor-table+)
                     (#\b +terrain-floor-bed+)
                     (#\c +terrain-floor-cabinet+)
                     (#\C +terrain-floor-crate+)
                     (#\B +terrain-floor-bookshelf+)
                     (#\+ +terrain-door-closed+)
                     (#\' +terrain-door-open+)
                     (#\0 +terrain-wall-earth+)
                     (#\Space +terrain-floor-air+)
                     (#\u +terrain-slope-stone-up+)
                     (#\d +terrain-slope-stone-down+)
                     (#\* +terrain-wall-bush+)
                     (#\| +terrain-wall-lantern+)
                     (#\G +terrain-wall-grave+))
          when tt
            do (setf (aref template-level (+ x x1) (+ y y1) z) tt))))

(defun level-city-reserve-build-on-grid (template-building-id gx gy gz reserved-level)
  (destructuring-bind (dx . dy) (building-grid-dim (get-building-type template-building-id))
    (loop for y1 from 0 below dy do
      (loop for x1 from 0 below dx do
        (setf (aref reserved-level (+ gx x1) (+ gy y1) gz) template-building-id)))
    ))

(defun level-city-can-place-build-on-grid (template-building-id gx gy gz reserved-level)
  (destructuring-bind (dx . dy) (building-grid-dim (get-building-type template-building-id))
    ;; if the staring point of the building + its dimensions) is more than level dimensions - fail
    (when (or (> (+ gx dx) (array-dimension reserved-level 0))
              (> (+ gy dy) (array-dimension reserved-level 1)))
      (return-from level-city-can-place-build-on-grid nil))
    
    ;; if any of the grid tiles that the building is going to occupy are already reserved - fail
    (loop for y1 from 0 below dy do
      (loop for x1 from 0 below dx do
        (when (/= (aref reserved-level (+ gx x1) (+ gy y1) gz) +building-city-free+)
          (return-from level-city-can-place-build-on-grid nil))
            ))
    ;; all checks done - success
    t
    ))

(defun level-place-birch-mature-1 (template-level x y z)
  ;; (0, 0) is the top left corner
  ;; z = 2
  (setf (aref template-level (+ x 0) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 0)) +terrain-tree-birch-trunk+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  
  ;; z = 3
  (setf (aref template-level (+ x 0) (+ y 0) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 1)) +terrain-floor-branches+)
  ;;(setf (aref template-level (+ x 0) (+ y 2) (+ z 1)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 1)) +terrain-tree-birch-trunk+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 1)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 2) (+ y 0) (+ z 1)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 1)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 1)) +terrain-floor-leaves+)
  
  ;; z = 4
  ;;(setf (aref template-level (+ x 0) (+ y 0) (+ z 2)) +terrain-floor-grass+)
  ;;(setf (aref template-level (+ x 0) (+ y 1) (+ z 2)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 2) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 2)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 0) (+ z 2)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 2) (+ y 1) (+ z 2)) +terrain-floor-grass+)
  ;;(setf (aref template-level (+ x 2) (+ y 2) (+ z 2)) +terrain-floor-grass+)
  )

(defun level-place-birch-mature-2 (template-level x y z)
  ;; (0, 0) is the top left corner
  ;; z = 2
  (setf (aref template-level (+ x 0) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 0)) +terrain-tree-birch-trunk+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  
  ;; z = 3
  (setf (aref template-level (+ x 0) (+ y 0) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 1)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 0) (+ y 2) (+ z 1)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 1)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 1)) +terrain-tree-birch-trunk+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 1)) +terrain-floor-branches+)
  ;;(setf (aref template-level (+ x 2) (+ y 0) (+ z 1)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 1)) +terrain-floor-leaves+)
  
  ;; z = 4
  ;;(setf (aref template-level (+ x 0) (+ y 0) (+ z 2)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 0) (+ y 2) (+ z 2)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 1) (+ y 0) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 2)) +terrain-floor-branches+)
  ;;(setf (aref template-level (+ x 1) (+ y 2) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 0) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 2)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 2) (+ y 2) (+ z 2)) +terrain-floor-grass+)
  )

(defun level-place-birch-mature-3 (template-level x y z)
  ;; (0, 0) is the top left corner
  ;; z = 2
  (setf (aref template-level (+ x 0) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 0)) +terrain-tree-birch-trunk+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  
  ;; z = 3
  ;;(setf (aref template-level (+ x 0) (+ y 0) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 0) (+ y 2) (+ z 1)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 1)) +terrain-tree-birch-trunk+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 0) (+ z 1)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 1)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 2) (+ y 2) (+ z 1)) +terrain-floor-leaves+)
  
  ;; z = 4
  (setf (aref template-level (+ x 0) (+ y 0) (+ z 2)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 2)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 0) (+ y 2) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 2)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 2)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 2) (+ y 0) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 2)) +terrain-floor-branches+)
  )

(defun level-place-birch-mature-4 (template-level x y z)
  ;; (0, 0) is the top left corner
  ;; z = 2
  (setf (aref template-level (+ x 0) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 0)) +terrain-tree-birch-trunk+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  
  ;; z = 3
  (setf (aref template-level (+ x 0) (+ y 0) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 1)) +terrain-floor-branches+)
  ;;(setf (aref template-level (+ x 0) (+ y 2) (+ z 1)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 1)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 1)) +terrain-tree-birch-trunk+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 1)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 2) (+ y 0) (+ z 1)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 1)) +terrain-floor-leaves+)
  
  ;; z = 4
  (setf (aref template-level (+ x 0) (+ y 0) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 2)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 0) (+ y 2) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 2)) +terrain-tree-birch-trunk+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 2)) +terrain-floor-branches+)
  ;;(setf (aref template-level (+ x 2) (+ y 0) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 2)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 2)) +terrain-floor-leaves+)

  ;; z = 5
  ;;(setf (aref template-level (+ x 0) (+ y 0) (+ z 3)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 3)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 0) (+ y 2) (+ z 3)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 0) (+ z 3)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 3)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 3)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 2) (+ y 0) (+ z 3)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 3)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 2) (+ y 2) (+ z 3)) +terrain-floor-branches+)
  )

(defun level-place-oak-mature-1 (template-level x y z)
  ;; (0, 0) is the top left corner
  ;; z = 2
  (setf (aref template-level (+ x 0) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 3) (+ z 0)) +terrain-floor-grass+)

  (setf (aref template-level (+ x 1) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 0)) +terrain-tree-oak-trunk-nw+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 0)) +terrain-tree-oak-trunk-sw+)
  (setf (aref template-level (+ x 1) (+ y 3) (+ z 0)) +terrain-floor-grass+)

  (setf (aref template-level (+ x 2) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 0)) +terrain-tree-oak-trunk-ne+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 0)) +terrain-tree-oak-trunk-se+)
  (setf (aref template-level (+ x 2) (+ y 3) (+ z 0)) +terrain-floor-grass+)

  (setf (aref template-level (+ x 3) (+ y 0) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 3) (+ y 1) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 3) (+ y 2) (+ z 0)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 3) (+ y 3) (+ z 0)) +terrain-floor-grass+)
  
  ;; z = 3
  ;;(setf (aref template-level (+ x 0) (+ y 0) (+ z 1)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 1)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 0) (+ y 2) (+ z 1)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 0) (+ y 3) (+ z 1)) +terrain-floor-grass+)

  (setf (aref template-level (+ x 1) (+ y 0) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 1)) +terrain-tree-oak-trunk-nw+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 1)) +terrain-tree-oak-trunk-sw+)
  (setf (aref template-level (+ x 1) (+ y 3) (+ z 1)) +terrain-floor-branches+)

  (setf (aref template-level (+ x 2) (+ y 0) (+ z 1)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 1)) +terrain-tree-oak-trunk-ne+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 1)) +terrain-tree-oak-trunk-se+)
  (setf (aref template-level (+ x 2) (+ y 3) (+ z 1)) +terrain-floor-leaves+)

  ;;(setf (aref template-level (+ x 3) (+ y 0) (+ z 1)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 3) (+ y 1) (+ z 1)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 3) (+ y 2) (+ z 1)) +terrain-floor-branches+)
  ;;(setf (aref template-level (+ x 3) (+ y 3) (+ z 1)) +terrain-floor-grass+)
  
  ;; z = 4
  ;;(setf (aref template-level (+ x 0) (+ y 0) (+ z 2)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 0) (+ y 2) (+ z 2)) +terrain-floor-branches+)
  ;;(setf (aref template-level (+ x 0) (+ y 3) (+ z 2)) +terrain-floor-grass+)

  (setf (aref template-level (+ x 1) (+ y 0) (+ z 2)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 2)) +terrain-tree-oak-trunk-nw+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 2)) +terrain-tree-oak-trunk-sw+)
  (setf (aref template-level (+ x 1) (+ y 3) (+ z 2)) +terrain-floor-leaves+)

  (setf (aref template-level (+ x 2) (+ y 0) (+ z 2)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 2)) +terrain-tree-oak-trunk-ne+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 2)) +terrain-tree-oak-trunk-se+)
  (setf (aref template-level (+ x 2) (+ y 3) (+ z 2)) +terrain-floor-branches+)

  ;;(setf (aref template-level (+ x 3) (+ y 0) (+ z 2)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 3) (+ y 1) (+ z 2)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 3) (+ y 2) (+ z 2)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 3) (+ y 3) (+ z 2)) +terrain-floor-grass+)

  ;; z = 5
  ;;(setf (aref template-level (+ x 0) (+ y 0) (+ z 3)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 0) (+ y 1) (+ z 3)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 0) (+ y 2) (+ z 3)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 0) (+ y 3) (+ z 3)) +terrain-floor-grass+)

  (setf (aref template-level (+ x 1) (+ y 0) (+ z 3)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 1) (+ y 1) (+ z 3)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 1) (+ y 2) (+ z 3)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 1) (+ y 3) (+ z 3)) +terrain-floor-leaves+)

  (setf (aref template-level (+ x 2) (+ y 0) (+ z 3)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 2) (+ y 1) (+ z 3)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 2) (+ y 2) (+ z 3)) +terrain-floor-branches+)
  (setf (aref template-level (+ x 2) (+ y 3) (+ z 3)) +terrain-floor-leaves+)

  ;;(setf (aref template-level (+ x 3) (+ y 0) (+ z 3)) +terrain-floor-grass+)
  (setf (aref template-level (+ x 3) (+ y 1) (+ z 3)) +terrain-floor-leaves+)
  (setf (aref template-level (+ x 3) (+ y 2) (+ z 3)) +terrain-floor-leaves+)
  ;;(setf (aref template-level (+ x 3) (+ y 3) (+ z 3)) +terrain-floor-grass+)
  )
