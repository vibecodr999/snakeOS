;Привет всем,кому интересно,оставил для вас подсказки
[org 0x7c00]

init_game:
    ; Инициализация видео VGA 13h (320x200, 256 цветов)
    mov ax, 0x0013
    int 0x10
    mov ax, 0xA000
    mov es, ax

    ; Начальные настройки (координаты в блоках 4x4 пикселя)
    mov word [snake_head_x], 40  ; Центр экрана по X (40 * 4 = 160)
    mov word [snake_head_y], 25  ; Центр экрана по Y (25 * 4 = 100)
    mov word [direction_x], 1    ; Стартовое движение вправо
    mov word [direction_y], 0
    mov word [snake_size], 4     ; Стартовая длина змейки
    mov word [score], 0          ; Обнуляем счет очков

    call spawn_apple
    call draw_score

game_loop:
    ; Игровой цикл и задержка времени (скорость игры)
    mov cx, 0x01
    mov dx, 0x4240
    mov ah, 0x86
    int 0x15

    ; Опрос клавиатуры (BIOS Interrupt 16h)
    mov ah, 0x01
    int 0x16
    jz move_logic
    mov ah, 0x00
    int 0x16

    ; Проверка нажатых стрелок управления
    cmp ah, 0x48
    je set_up
    cmp ah, 0x50
    je set_down
    cmp ah, 0x4B
    je set_left
    cmp ah, 0x4D
    je set_right
    jmp move_logic

set_up:
    mov word [direction_x], 0
    mov word [direction_y], -1
    jmp move_logic
set_down:
    mov word [direction_x], 0
    mov word [direction_y], 1
    jmp move_logic
set_left:
    mov word [direction_x], -1
    mov word [direction_y], 0
    jmp move_logic
set_right:
    mov word [direction_x], 1
    mov word [direction_y], 0

move_logic:
    ; 1. Стираем старый хвост змейки (рисуем черный блок)
    mov bx, [snake_size]
    dec bx
    shl bx, 2
    mov ax, [snake_body + bx]
    mov dx, [snake_body + bx + 2]
    mov cl, 0x00
    call draw_block

    ; 2. Сдвигаем координаты хвоста в ОЗУ
    mov cx, [snake_size]
    dec cx
    mov si, cx
    shl si, 2
.shift_loop:
    mov ax, [snake_body + si - 4]
    mov [snake_body + si], ax
    mov ax, [snake_body + si - 2]
    mov [snake_body + si + 2], ax
    sub si, 4
    loop .shift_loop

    ; Сохраняем текущую позицию головы в массив тела
    mov ax, [snake_head_x]
    mov [snake_body], ax
    mov dx, [snake_head_y]
    mov [snake_body + 2], dx

    ; 3. Двигаем голову змейки в выбранном направлении
    mov ax, [snake_head_x]
    add ax, [direction_x]
    mov [snake_head_x], ax
    mov dx, [snake_head_y]
    add dx, [direction_y]
    mov [snake_head_y], dx

    ; 4. Проверка столкновения с границами экрана (смерть)
    cmp ax, 0
    jl game_over
    cmp ax, 80                   ; 320 пикселей / 4 = 80 блоков в ширину
    jge game_over
    cmp dx, 0
    jl game_over
    cmp dx, 50                   ; 200 пикселей / 4 = 50 блоков в высоту
    jge game_over

    ; 5. Проверка поедания яблока
    cmp ax, [apple_x]
    jne .draw_game
    cmp dx, [apple_y]
    jne .draw_game

    ; Еда съедена!
    inc word [score]
    inc word [snake_size]
    call draw_score
    call spawn_apple

.draw_game:
    ; Рисуем яблоко (красный блок)
    mov ax, [apple_x]
    mov dx, [apple_y]
    mov cl, 0x28                 ; Код красного цвета в палитре VGA
    call draw_block

    ; Рисуем голову змейки (зеленый блок)
    mov ax, [snake_head_x]
    mov dx, [snake_head_y]
    mov cl, 0x0A                 ; Код ярко-зеленого цвета
    call draw_block

    jmp game_loop

game_over:
    ; Ожидание нажатия клавиши 'R' (перезапуск игры)
    mov ah, 0x00
    int 0x16
    cmp al, 'r'
    je init_game
    cmp al, 'R'
    je init_game
    jmp game_over

spawn_apple:
    ; Генерация псевдослучайных координат X и Y через таймер BIOS
    mov ah, 0x00
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov cx, 75
    div cx
    inc dx
    mov [apple_x], dx

    mov ah, 0x00
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov cx, 45
    div cx
    inc dx
    mov [apple_y], dx
    ret

draw_score:
    ; Вывод счетчика очков в текстовом режиме в левый верхний угол
    mov ah, 0x02
    mov bh, 0
    mov dh, 0                    ; Строка 0
    mov dl, 0                    ; Столбец 0
    int 0x10

    mov ax, [score]
    add al, '0'                  ; Конвертация цифры в символ ASCII
    mov ah, 0x0E
    mov bl, 0x0F                 ; Белый цвет текста
    int 0x10
    ret

draw_block:
    ; Функция рисования крупного блока 4x4 пикселя
    pusha
    ; Формула смещения в видеопамяти VGA: Y * 4 * 320 + X * 4
    shl dx, 2
    mov bx, 320
    imul dx, bx
    shl ax, 2
    add dx, ax
    mov di, dx

    mov ch, 4                    ; Отрисовка 4 строк в высоту
.row_loop:
    mov al, 4                    ; Отрисовка 4 пикселей в ширину
.pixel_loop:
    mov [es:di], cl
    inc di
    dec al                       ; Использование исправленного 8-битного регистра AL
    jnz .pixel_loop
    add di, 316                  ; Переход на следующую физическую строку экрана (320 - 4)
    dec ch
    jnz .row_loop
    popa
    ret

; Блок переменных
direction_x dw 0
direction_y dw 0
snake_head_x dw 0
snake_head_y dw 0
snake_size dw 0
score dw 0
apple_x dw 0
apple_y dw 0

; Динамический массив тела змейки живет в ОЗУ сразу за пределами 512 байт кода
snake_body equ 0x7E00

; Выравнивание под размер загрузочного сектора (строго 512 байт)
times 510 - ($ - $$) db 0
dw 0xaa55
