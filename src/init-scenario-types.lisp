(in-package :cotd)

(set-scenario-feature (make-scenario-feature :id +weather-type-clear+
                                             :type +scenario-feature-weather+
                                             :func nil))

(set-scenario-feature (make-scenario-feature :id +weather-type-snow+
                                             :type +scenario-feature-weather+
                                             :func #'(lambda (layout-func post-processing-func-list mob-func-list game-event-list)
                                                       (push #'change-level-to-snow post-processing-func-list)
                                                       (pushnew +game-event-snow-falls+ game-event-list)
                                                       
                                                       (values layout-func post-processing-func-list mob-func-list game-event-list))))

(set-scenario-feature (make-scenario-feature :id +city-layout-test+
                                             :type +scenario-feature-city-layout+
                                             :func #'(lambda (layout-func post-processing-func-list mob-func-list game-event-list)
                                                       (push #'test-level-place-mobs mob-func-list)
                                                       (push #'(lambda (world mob-template-list) (declare (ignore world mob-template-list))
                                                                 (setf *player* (make-instance 'player :mob-type +mob-type-angel+)))
                                                             mob-func-list)

                                                       (pushnew +game-event-lose-game+ game-event-list)
                                                       
                                                       (values layout-func post-processing-func-list mob-func-list game-event-list))))

(set-scenario-feature (make-scenario-feature :id +city-layout-test+
                                             :type +scenario-feature-city-layout+ :debug t
                                             :func #'(lambda (layout-func post-processing-func-list mob-func-list game-event-list)
                                                       (setf layout-func #'(lambda () (create-template-test-city *max-x-level* *max-y-level* nil)))
                                                       
                                                       (values layout-func post-processing-func-list mob-func-list game-event-list))))

(set-scenario-feature (make-scenario-feature :id +city-layout-normal+
                                             :type +scenario-feature-city-layout+
                                             :func #'(lambda (layout-func post-processing-func-list mob-func-list game-event-list)
                                                       (setf layout-func #'(lambda () (create-template-city *max-x-level* *max-y-level* #'get-max-buildings-normal #'get-reserved-buildings-normal nil)))
                                                       (push +game-event-military-arrive+ game-event-list)
                                                       
                                                       (values layout-func post-processing-func-list mob-func-list game-event-list))))

(set-scenario-feature (make-scenario-feature :id +city-layout-river+
                                             :type +scenario-feature-city-layout+
                                             :func #'(lambda (layout-func post-processing-func-list mob-func-list game-event-list)
                                                       (setf layout-func #'(lambda () (create-template-city *max-x-level* *max-y-level* #'get-max-buildings-river #'get-reserved-buildings-river #'place-reserved-buildings-river)))
                                                       (push +game-event-military-arrive+ game-event-list)
                                                       
                                                       (values layout-func post-processing-func-list mob-func-list game-event-list))))

(set-scenario-feature (make-scenario-feature :id +city-layout-port+
                                             :type +scenario-feature-city-layout+
                                             :func #'(lambda (layout-func post-processing-func-list mob-func-list game-event-list)
                                                       (let ((r (random 4)))
                                                         (setf layout-func #'(lambda () (create-template-city *max-x-level* *max-y-level* #'get-max-buildings-port #'get-reserved-buildings-port
                                                                                                              #'(lambda (reserved-level)
                                                                                                                  (let ((result))
                                                                                                                    (cond
                                                                                                                      ((= r 0) (setf result (place-reserved-buildings-port-n reserved-level))) ;; north
                                                                                                                      ((= r 1) (setf result (place-reserved-buildings-port-s reserved-level))) ;; south
                                                                                                                      ((= r 2) (setf result (place-reserved-buildings-port-e reserved-level))) ;; east
                                                                                                                      ((= r 3) (setf result (place-reserved-buildings-port-w reserved-level)))) ;; west
                                                                                                                    result)))))
                                                         (cond
                                                           ((= r 0) (push +game-event-military-arrive-port-n+ game-event-list)) ;; north
                                                           ((= r 1) (push +game-event-military-arrive-port-s+ game-event-list)) ;; south
                                                           ((= r 2) (push +game-event-military-arrive-port-e+ game-event-list)) ;; east
                                                           ((= r 3) (push +game-event-military-arrive-port-w+ game-event-list))) ;; west
                                                         )
                                                       
                                                       (values layout-func post-processing-func-list mob-func-list game-event-list))))

(set-scenario-feature (make-scenario-feature :id +player-faction-player+
                                             :type +scenario-feature-player-faction+ :debug t
                                             :func #'(lambda (layout-func post-processing-func-list mob-func-list game-event-list)
                                                       ;; it is important that the player setup function is the last to be pushed so that it is the first to be processed, otherwise everything will break
                                                       (push #'populate-world-with-angels mob-func-list)
                                                       (push #'populate-world-with-demons mob-func-list)
                                                       (push #'create-mobs-from-template mob-func-list)
                                                       (push #'(lambda (world mob-template-list) (declare (ignore world mob-template-list))
                                                                 (setf *player* (make-instance 'player :mob-type +mob-type-player+))
                                                                 (setf (x *player*) 1 (y *player*) 1)
                                                                 (add-mob-to-level-list (level *world*) *player*))
                                                             mob-func-list)
                                                       
                                                       (push +game-event-lose-game+ game-event-list)
                                                       
                                                       (values layout-func post-processing-func-list mob-func-list game-event-list))))

(set-scenario-feature (make-scenario-feature :id +player-faction-test+
                                             :type +scenario-feature-player-faction+ :debug t
                                             :func #'(lambda (layout-func post-processing-func-list mob-func-list game-event-list)
                                                       ;; it is important that the player setup function is the last to be pushed so that it is the first to be processed, otherwise everything will break
                                                       (push #'test-level-place-mobs mob-func-list)
                                                       (push #'(lambda (world mob-template-list) (declare (ignore world mob-template-list)) (setf *player* (make-instance 'player :mob-type +mob-type-angel+))) mob-func-list)
                                                       
                                                       (push +game-event-lose-game+ game-event-list)
                                                       
                                                       (values layout-func post-processing-func-list mob-func-list game-event-list))))

(set-scenario-feature (make-scenario-feature :id +player-faction-angels+
                                             :type +scenario-feature-player-faction+
                                             :func #'(lambda (layout-func post-processing-func-list mob-func-list game-event-list)
                                                       ;; it is important that the player setup function is the last to be pushed so that it is the first to be processed, otherwise everything will break
                                                       (push #'populate-world-with-angels mob-func-list)
                                                       (push #'populate-world-with-demons mob-func-list)
                                                       (push #'create-mobs-from-template mob-func-list)
                                                       (push #'(lambda (world mob-template-list) (declare (ignore mob-template-list))
                                                                 (setf *player* (make-instance 'player :mob-type +mob-type-angel+))
                                                                 (find-unoccupied-place-for-angel world *player*))
                                                             mob-func-list)
                                                       
                                                       (push +game-event-lose-game+ game-event-list)
                                                       (push +game-event-win-for-angels+ game-event-list)
                                                       
                                                       (values layout-func post-processing-func-list mob-func-list game-event-list))))

(set-scenario-feature (make-scenario-feature :id +player-faction-demons+
                                             :type +scenario-feature-player-faction+
                                             :func #'(lambda (layout-func post-processing-func-list mob-func-list game-event-list)
                                                       ;; it is important that the player setup function is the last to be pushed so that it is the first to be processed, otherwise everything will break
                                                       (push #'populate-world-with-angels mob-func-list)
                                                       (push #'populate-world-with-demons mob-func-list)
                                                       (push #'create-mobs-from-template mob-func-list)
                                                       (push #'(lambda (world mob-template-list) (declare (ignore mob-template-list))
                                                                 (setf *player* (make-instance 'player :mob-type +mob-type-imp+))
                                                                 (find-unoccupied-place-for-demon world *player*))
                                                             mob-func-list)
                                                       
                                                       (push +game-event-lose-game+ game-event-list)
                                                       (push +game-event-win-for-demons+ game-event-list)
                                                       
                                                       (values layout-func post-processing-func-list mob-func-list game-event-list))))