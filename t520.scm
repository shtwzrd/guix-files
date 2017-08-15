(use-modules (gnu) (gnu services) (guix gexp) (gnu system nss) (gnu services xorg))
(use-service-modules networking shepherd)
(use-package-modules admin linux certs xorg fonts vim freedesktop)

(define powertop-tuning-service-type
  (shepherd-service-type
   'powertop-tuning
   (lambda _
     (shepherd-service
      (documentation "Auto-tune powertop tunables to increase battery life")
      (provision '(powertop-tuning))
      (start #~(lambda _
                 (zero? (system* (string-append #$powertop "/sbin/powertop")
                                 "--auto-tune"))))
      (respawn? #f)))))

(define wpa-supplicant-service-type
  (shepherd-service-type
   'wpa-supplicant
   (lambda (arg)
     (let ((interface (car arg))
           (config-file (cadr arg)))
      (shepherd-service
       (documentation "WiFi association daemon")
       (provision '(wpa-supplicant))
       (start #~(make-forkexec-constructor
                 (list (string-append #$wpa-supplicant-minimal "/sbin/wpa_supplicant")
                       "-i" #$interface
                       "-c" #$config-file)))
       (stop #~(make-kill-destructor))
       (respawn? #t))))))

(define (powertop-tuning-service)
  (service powertop-tuning-service-type '()))

(define (wpa-supplicant-service interface config-file)
  (service wpa-supplicant-service-type (list interface config-file)))

(operating-system
  (host-name "t520")
  (timezone "Europe/Copenhagen")
  (locale "en_US.UTF-8")

  (bootloader (grub-configuration (device "/dev/sda")))

  (file-systems (cons (file-system
                        (device "my-root")
                        (title 'label)
                        (mount-point "/")
                        (type "ext4"))
                      %base-file-systems))

  (users (cons (user-account
                (name "blu")
                (group "users")
                (supplementary-groups '("wheel" "netdev"
					"video" "input"))
                (home-directory "/home/blu"))
               %base-user-accounts))

  ;; This is where we specify system-wide packages.
  (packages (cons* nss-certs         ;for HTTPS access
                   font-dejavu
                   xf86-video-nouveau
                   xf86-video-intel
                   xf86-input-libinput
                   xorg-server
		   libinput
                   xinit

                   vim

                   %base-packages))

 (setuid-programs (cons* #~(string-append #$xorg-server "/bin/Xorg")
                         %setuid-programs))

  (services (cons* (powertop-tuning-service)
                   (wpa-supplicant-service "wlp2s0" "/home/blu/.config/wpa_supplicant.conf")
                   (dhcp-client-service)
                   %base-services))

  ;; Allow resolution of '.local' host names with mDNS.
  (name-service-switch %mdns-host-lookup-nss))
