package main

import rl "vendor:raylib"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"
import "core:mem"
import "core:fmt"

MAX_INPUT_CHARS : int : 7
w_width         : i32 : 1600
w_height        : i32 : 900

Input_Box :: struct {
    rect: rl.Rectangle,
    text: string,
    key: rune,
    keys: [MAX_INPUT_CHARS]rune,
    char_count: int,
    mouse_on_text: bool,
    color: rl.Color,
    frames_counter: int,
    title: cstring
}

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
    // Allow more bytes if increasing the MAX_INPUT_CHARS number
    // buf will receive an int type, which is 4 to 8 bytes in size, from the get_input_box fn
    buf: [8]byte
    node_data_string := strconv.itoa(buf[:], node.data)
    cstr_node_data := strings.clone_to_cstring(node_data_string)
    defer delete(cstr_node_data)
    rl.DrawText(cstr_node_data, node.posx - i32((node.radius / 2)), node.posy - i32((node.radius / 2)), 20, color)
    
    // Lines
    if node.left != nil {
        i: i32 = i32(node.radius)
        rl.DrawLine(node.posx - i, node.posy, node.left.posx, node.left.posy - i, color)
        left_flagged_node := draw_node(node.left, mouse_pos)
        if left_flagged_node != nil {
            return left_flagged_node
        }
    }
    
    // Lines
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

update_positions :: proc(node: ^Node, x: int, y: int, x_offset: int, y_offset: int) {
    if node == nil {
        return
    }

    node.posx = i32(x)
    node.posy = i32(y)

    if node.left != nil {
        update_positions(node.left, x - x_offset, y + y_offset, x_offset / 2, y_offset)
    }

    if node.right != nil {
        update_positions(node.right, x + x_offset, y + y_offset, x_offset / 2, y_offset)
    }
}

get_input_box :: proc(box: ^Input_Box, tree: ^Avltree) -> (result: int, ok: bool) {
    tree := tree
    box := box
    if box.mouse_on_text {
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

        if box.text != "" {
            delete(box.text) // free old string from memory 
        }

        box.text = utf8.runes_to_string(box.keys[:box.char_count]) // allocate new value

        if rl.IsKeyPressed(rl.KeyboardKey.ENTER) || rl.IsKeyPressed(rl.KeyboardKey.KP_ENTER) {
            ok = true
            result = strconv.atoi(box.text)
            box.char_count = 0
            delete(box.text) // ensure memory of the string is cleared when pressing enter
            box.text = ""
            for i := 0; i < len(box.keys); i += 1 {
                if box.keys[i] == 45 && i != 0 { // minus sign in the middle of a number
                    ok = false
                }
                box.keys[i] = 0
            }

            if !ok {
                return result, false
            }

            return result, true
        }
    }

    return result, false
}

draw_input_box :: proc(box: ^Input_Box) {
    rl.DrawText(box.title, i32(box.rect.x), i32(box.rect.y) / 2 - 5, 25, rl.MAROON)
    rl.DrawRectangleRec(box.rect, rl.LIGHTGRAY)
    if box.mouse_on_text {
        rl.DrawRectangleLines(i32(box.rect.x), i32(box.rect.y), i32(box.rect.width), i32(box.rect.height), rl.RED)
    } else {
        rl.DrawRectangleLines(i32(box.rect.x), i32(box.rect.y), i32(box.rect.width), i32(box.rect.height), box.color)
        box.frames_counter = 0
    }
    cstr_box_text := strings.clone_to_cstring(box.text)
    defer delete(cstr_box_text)
    rl.DrawText(cstr_box_text, i32(box.rect.x + 5), i32(box.rect.y + 8), 40, rl.MAROON)

    if box.mouse_on_text {
        if box.char_count < MAX_INPUT_CHARS {
            // Draw blinking underscore char
            if ((box.frames_counter/20)%2) == 0 {
                rl.DrawText("_", i32(box.rect.x) + 8 + rl.MeasureText(cstr_box_text, 40), i32(box.rect.y) + 12, 40, rl.MAROON)
            }
        }
        box.frames_counter += 1
    }
}

main :: proc() {
    /*track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}*/

    tree: Avltree
    rl.InitWindow(w_width, w_height, "AVL Tree Visualization")
    defer {
        rl.CloseWindow()
        free_tree(&tree)
    }

    camera: rl.Camera2D
    camera.zoom = 1

    insert_box: Input_Box
    insert_box.rect = {f32(w_width) - 195, 40, 175, 50 }
    insert_box.color = rl.LIGHTGRAY
    insert_box.title = "INSERT"

    delete_box: Input_Box
    delete_box.rect = {20, 40, 175, 50 }
    delete_box.color = rl.LIGHTGRAY
    delete_box.title = "DELETE"

    rl.SetTargetFPS(60);

    add_sum_num: int
    add_minus_num: int = -1

    height_offset_x: int = 1
    previous_height: int = -1

    flagged_node: ^Node = nil

    for !rl.WindowShouldClose() {
        // Update
        //----------------------------------------------------------------------------------
        if rl.CheckCollisionPointRec(rl.GetMousePosition(), insert_box.rect) do insert_box.mouse_on_text = true
        else do insert_box.mouse_on_text = false
        if rl.CheckCollisionPointRec(rl.GetMousePosition(), delete_box.rect) do delete_box.mouse_on_text = true
        else do delete_box.mouse_on_text = false

        rl.SetMouseCursor(rl.MouseCursor.DEFAULT)

        // Capture input numbers on box
        if insert_box.mouse_on_text {
            rl.SetMouseCursor(rl.MouseCursor.IBEAM)
            nums_ins: int
            ok: bool
            nums_ins, ok = get_input_box(&insert_box, &tree)
            if ok do insert(&tree, nums_ins, w_width/2, 200, 25)
        }

        if delete_box.mouse_on_text {
            rl.SetMouseCursor(rl.MouseCursor.IBEAM)
            nums_del: int
            ok: bool
            nums_del, ok = get_input_box(&delete_box, &tree)
            if ok do remove(&tree, nums_del)
        }
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
        if rl.IsKeyPressed(rl.KeyboardKey.A) {
            insert(&tree, add_sum_num, w_width/2, 200, 25)
            add_sum_num += 1
        } else if rl.IsKeyPressed(rl.KeyboardKey.S) {
            insert(&tree, add_minus_num, w_width/2, 200, 25)
            add_minus_num -= 1
        } else if rl.IsKeyPressed(rl.KeyboardKey.D) {
            add_sum_num = 0
            add_minus_num = -1
        }
        ////

        // 2D moving camera
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
        // End 2D moving camera

        // Add an offset to X so nodes are separated when they get close to each other
        if tree.root != nil {
            added_offset_x: bool
            current_height: int = int(tree.root.height)

            if (current_height >= 7 && (previous_height == -1 || previous_height < 7)) {
                height_offset_x += 1
                added_offset_x = true
            } else if added_offset_x && current_height < 7 {
                // Reset if height goes below 7 after previously adding offset
                added_offset_x = false
                height_offset_x -= 1
            }

            // Check subsequent changes in height
            if current_height != previous_height {
                if current_height >= 7 {
                    height_offset_x += 1 + (current_height - 7) // Increase increment for taller trees
                } else {
                    height_offset_x = 1 // Reset if height is below 7
                }
                previous_height = current_height
            }
        }
        // End add an offset

        flagged_node = nil
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        rl.DrawText("Mouse left button drag to move, wheel to zoom.", 10, w_height - 30, 20, rl.MAROON)
        rl.DrawText("Place mouse on node, left click to delete, right click to delete the subtree.", 10, w_height - 60, 20, rl.MAROON)
        rl.DrawText("Press A and S to insert incrementally, D to reset the increments.", 10, w_height - 90, 20, rl.MAROON)
        rl.DrawText("Place mouse on the input box and enter numbers.", 10, w_height - 120, 20, rl.MAROON)
        
        draw_input_box(&insert_box)
        draw_input_box(&delete_box)

        // Draw Nodes
        rl.BeginMode2D(camera) // Only things between this and EndMode2D will move

        flagged_node = draw_node(tree.root, game_mouse_pos)
        update_positions(tree.root, int(w_width/2), 50, 400 * height_offset_x, 100)

        rl.EndMode2D()
        // End Draw Nodes
        
        rl.EndDrawing()
        //----------------------------------------------------------------------------------
    }
}