package main

import rl "vendor:raylib"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

MAX_INPUT_CHARS : int : 4
w_width         : i32 : 1600
w_height        : i32 : 900

draw_node :: proc(node: ^Node, mouse_pos: rl.Vector2) -> ^Node {
    if node == nil {
        return nil
    }

    is_hovered := rl.CheckCollisionPointCircle(mouse_pos, [2]f32{f32(node.posx), f32(node.posy)}, node.radius)

    color := rl.WHITE
    if is_hovered {
        color = rl.RED
        if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
            return node
        } else if rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) {
            return node
        }
    }

    rl.DrawCircleLines(node.posx, node.posy, node.radius, color)
    buf: [4]byte
    node_data_string := strconv.itoa(buf[:], node.data)
    node_data_cstring := strings.clone_to_cstring(node_data_string)
    rl.DrawText(node_data_cstring, node.posx - i32((node.radius / 2)), node.posy - i32((node.radius / 2)), 20, color)
    
    // Lines
    if node.left != nil {
        i: i32 = i32(node.radius)
        rl.DrawLine(node.posx - i, node.posy, node.left.posx, node.left.posy - i, color)
        left_flagged_node := draw_node(node.left, mouse_pos)
        if left_flagged_node != nil {
            return left_flagged_node
        }
    }
    
    if node.right != nil {
        i: i32 = i32(node.radius)
        rl.DrawLine(node.posx + i, node.posy, node.right.posx, node.right.posy - i, color)
        right_flagged_node := draw_node(node.right, mouse_pos)
        if right_flagged_node != nil {
            return right_flagged_node
        }
    }

    return nil
}

update_positions :: proc(node: ^Node, x: i32, y: i32, x_offset: i32, y_offset: i32) {
    if node == nil {
        return
    }

    node.posx = x
    node.posy = y

    if node.left != nil {
        update_positions(node.left, x - x_offset, y + y_offset, x_offset / 2, y_offset)
    }

    if node.right != nil {
        update_positions(node.right, x + x_offset, y + y_offset, x_offset / 2, y_offset)
    }
}

get_input_box :: proc(box: ^Input_Box, tree: ^Avltree) {
    tree := tree
    box := box
    if rl.CheckCollisionPointRec(rl.GetMousePosition(), box.rect) do box.mouse_on_text = true
        else do box.mouse_on_text = false

        // Capture input numbers on insert box
        if box.mouse_on_text {
            rl.SetMouseCursor(rl.MouseCursor.IBEAM)
            box.key = rl.GetCharPressed()

            for box.key > 0 {
                // 45 is utf-8 for '-', 48 to 57 are numbers from 0 to 9
                if (box.key == 45 || (box.key >= 48) && (box.key <= 57)) && box.char_count < MAX_INPUT_CHARS {
                    box.keys[box.char_count] = box.key
                    box.char_count += 1
                }

                box.key = rl.GetCharPressed();
            }

            if rl.IsKeyPressed(rl.KeyboardKey.BACKSPACE) {
                box.char_count -= 1
                if box.char_count < 0 do box.char_count = 0
                box.keys[box.char_count] = 0
            }

            box.text = utf8.runes_to_string(box.keys[:])
            box.ctext = strings.clone_to_cstring(box.text)

            if rl.IsKeyPressed(rl.KeyboardKey.ENTER) || rl.IsKeyPressed(rl.KeyboardKey.KP_ENTER) {
                data: int = strconv.atoi(box.text)
                insert(tree, data, w_width/2, 200, 25)
                box.text = ""
                box.ctext = strings.clone_to_cstring(box.text)
                for i := 0; i < MAX_INPUT_CHARS; i += 1{
                    box.keys[i] = 0
                }
                box.char_count = 0
            }

            box.frames_counter += 1
        } else {
            rl.SetMouseCursor(rl.MouseCursor.DEFAULT)
            box.frames_counter = 0
        }
}

draw_input_box :: proc(box: ^Input_Box) {
    rl.DrawRectangleRec(box.rect, rl.LIGHTGRAY)
    if box.mouse_on_text {
        rl.DrawRectangleLines(i32(box.rect.x), i32(box.rect.y), i32(box.rect.width), i32(box.rect.height), rl.RED)
    } else {
        rl.DrawRectangleLines(i32(box.rect.x), i32(box.rect.y), i32(box.rect.width), i32(box.rect.height), rl.DARKGRAY)
    }
    rl.DrawText(box.ctext, i32(box.rect.x + 5), i32(box.rect.y + 8), 40, rl.MAROON)

    if box.mouse_on_text {
        if box.char_count < MAX_INPUT_CHARS {
            // Draw blinking underscore char
            if ((box.frames_counter/20)%2) == 0 {
                rl.DrawText("_", i32(box.rect.x) + 8 + rl.MeasureText(box.ctext, 40), i32(box.rect.y) + 12, 40, rl.MAROON)
            }
        }
    }
}

Input_Box :: struct {
    rect: rl.Rectangle,
    text: string,
    ctext: cstring,
    key: rune,
    keys: [MAX_INPUT_CHARS]rune,
    char_count: int,
    mouse_on_text: bool,
    color: rl.Color,
    frames_counter: int,
}

main :: proc() {
    tree: Avltree
    rl.InitWindow(w_width, w_height, "AVL Tree Visualization")
    defer {
        rl.CloseWindow()
        free_tree(&tree)
    }

    camera: rl.Camera2D
    camera.zoom = 1

    insert_box: Input_Box
    insert_box.rect = {f32(w_width) - 110, 10, 100, 50 }
    insert_box.color = rl.LIGHTGRAY

    delete_box: Input_Box
    delete_box.rect = {10, 10, 100, 50 }
    delete_box.color = rl.LIGHTGRAY

    rl.SetTargetFPS(60);

    add_sum_num: int
    add_minus_num: int

    flagged_node: ^Node = nil

    for !rl.WindowShouldClose() {
        // Update
        //----------------------------------------------------------------------------------
        if rl.CheckCollisionPointRec(rl.GetMousePosition(), insert_box.rect) do insert_box.mouse_on_text = true
        else do insert_box.mouse_on_text = false

        // Capture input numbers on box
        get_input_box(&insert_box, &tree)
        get_input_box(&delete_box, &tree)
        // End capture input numbers on box

        // Flagged for deletion
        if flagged_node != nil {
            if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
                remove(&tree, flagged_node.data)
            } else if rl.IsMouseButtonDown(rl.MouseButton.RIGHT) {
                remove_subtree(&tree, flagged_node.data)
            }
        }
        ////

        // Input keyboard
        if !insert_box.mouse_on_text {
            if rl.IsKeyPressed(rl.KeyboardKey.A) {
                insert(&tree, add_sum_num, w_width/2, 200, 25)
                add_sum_num += 1
            } else if rl.IsKeyPressed(rl.KeyboardKey.S) {
                insert(&tree, add_minus_num, w_width/2, 200, 25)
                add_minus_num -= 1
            } else if rl.IsKeyPressed(rl.KeyboardKey.D) {
                add_sum_num = 0
                add_minus_num = 0
            }
        }
        ///

        // Translate based on mouse left click
        if rl.IsMouseButtonDown(rl.MouseButton.LEFT) {
            delta: rl.Vector2 = rl.GetMouseDelta()
            delta = delta * (-1/camera.zoom)
            camera.target = camera.target + delta
        }

        wheel: f32 = rl.GetMouseWheelMove()
        // Get the world point that is under the mouse
        game_mouse_pos: rl.Vector2 = rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

        if wheel != 0 {
            // Set the offset to where the mouse is
            camera.offset = rl.GetMousePosition();
            
            // Set the target to match, so that the camera maps the world space point 
            // under the cursor to the screen space point under the cursor at any zoom
            camera.target = game_mouse_pos;
            
            // Zoom increment
            scaleFactor: f32 = 1 + (.25*abs(wheel));
            if (wheel < 0) do scaleFactor = 1/scaleFactor;
            camera.zoom = rl.Clamp(camera.zoom*scaleFactor, .125, 64);
        }

        flagged_node = nil
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        rl.DrawText("Place mouse on a node, left click to delete, right click to delete the subtree.", 10, w_height - 30, 20, rl.MAROON)
        rl.DrawText("Press A and S to insert incrementally, D to reset the increments.", 10, w_height - 60, 20, rl.MAROON)
        rl.DrawText("Place mouse on the input box and enter numbers.", 10, w_height - 90, 20, rl.MAROON)
        
        // Draw Insert Rectangle
        draw_input_box(&insert_box)
        // End Draw Insert Rectangle

        // Draw Insert Rectangle
        draw_input_box(&delete_box)
        // End Draw Insert Rectangle

        // Draw Nodes
        rl.BeginMode2D(camera)
        flagged_node = draw_node(tree.root, game_mouse_pos)

        update_positions(tree.root, w_width/2, 50, 400, 100)

        rl.EndMode2D()
        // End Draw Nodes
        
        rl.EndDrawing()
        //----------------------------------------------------------------------------------
    }
}