package main

Node :: struct {
    data: int,
    height: int,
    left: ^Node,
    right: ^Node,
    posx: i32,
    posy: i32,
    radius: f32,
}

Avltree :: struct {
    root: ^Node,
}

create_node :: proc(data: int, posx: i32, posy: i32, radius: f32) -> ^Node {
    new_node: ^Node = new(Node)
    new_node.data = data
    new_node.height = 1
    new_node.posx = posx
    new_node.posy = posy
    new_node.radius = radius
    return new_node
}

insert :: proc(tree: ^Avltree, data: int, posx: i32, posy: i32, radius: f32) {
    tree.root = _insert(tree.root, data, posx, posy, radius)
}

_insert :: proc(node: ^Node, data: int, posx: i32, posy: i32, radius: f32) -> ^Node {
    if node == nil {
        return create_node(data, posx, posy, radius)
    }

    if data < node.data {
        node.left = _insert(node.left, data, node.posx, node.posy, radius)
    } else if data > node.data {
        node.right = _insert(node.right, data, node.posx, node.posy, radius)
    }

    set_height(node)
    return rebalance(node)
}

remove :: proc(tree: ^Avltree, data: int) {
    tree.root = _remove(tree.root, data)
}

_remove :: proc(node: ^Node, data: int) -> ^Node {
    node := node
    if node == nil {
        return node
    }

    if data < node.data {
        node.left = _remove(node.left, data)
    } else if data > node.data {
        node.right = _remove(node.right, data)
    } else { // node found
        if (node.right == nil) || (node.left == nil) { // check if node has only one or no child
            tmp: ^Node = (node.left != nil) ? node.left : node.right
            if tmp == nil { // no child case
                tmp = node
                node = nil
            } else { // one child case
                // dereferencing to access and copy the values, without trail ^, the literal pointers would be copied
                // node to be "deleted" will be equal to either right or left
                node^ = tmp^
            }
            free(tmp)
        } else { // two children case
            tmp: ^Node = minimum(node.right) // the successor to right of the deleted node
            node.data = tmp.data // assign the data in the temp to the node to be "deleted"
            node.right = _remove(node.right, tmp.data) // remove the successor of the node
        }
    }

    if node == nil {
        return node
    }

    set_height(node)
    return rebalance(node)
}

remove_subtree :: proc(tree: ^Avltree, data: int) {
    tree.root = _remove_subtree(tree.root, data)
}

_remove_subtree :: proc(node: ^Node, data: int) -> ^Node {
    node := node
    if node == nil {
        return node
    }

    if data < node.data {
        node.left = _remove_subtree(node.left, data)
    } else if data > node.data {
        node.right = _remove_subtree(node.right, data)
    } else { // node found
        free_subtree(node)
        node = nil
        return node
    }

    set_height(node)
    return rebalance(node)
}

minimum :: proc(node: ^Node) -> ^Node {
    node := node
    for node.left != nil {
        node = node^.left
    }
    return node
}

free_tree :: proc(tree: ^Avltree) {
    free_subtree(tree.root)
    tree.root = nil
}

free_subtree :: proc(node: ^Node) {
    if node != nil {
        i: int = 1
        free_subtree(node.left)
        free_subtree(node.right)
        free(node)
    }
}

right_rotation :: proc(node: ^Node) -> ^Node {
    left_of_node: ^Node = node.left
    right_of_left_of_node: ^Node = left_of_node.right

    left_of_node.right = node
    node.left = right_of_left_of_node

    set_height(node)
    set_height(left_of_node)
    return left_of_node
}

left_rotation :: proc(node: ^Node) -> ^Node {
    right_of_node: ^Node = node.right
    left_of_right_of_node: ^Node = right_of_node.left

    right_of_node.left = node
    node.right = left_of_right_of_node
    
    set_height(node)
    set_height(right_of_node)
    return right_of_node
}

rebalance :: proc(node: ^Node) -> ^Node {
    balance: int = balance_factor(node)
    
    if balance > 1 && balance_factor(node.left) >= 0 {
        return right_rotation(node)
    }

    if balance < -1 && balance_factor(node.right) <= 0 {
        return left_rotation(node)
    }

    if balance > 1 && balance_factor(node.left) <= 0 {
        node.left = left_rotation(node.left)
        return right_rotation(node)
    }

    if balance < -1 && balance_factor(node.right) >= 0 {
        node.right = right_rotation(node.right)
        return left_rotation(node)
    }

    return node
}

height :: proc(node: ^Node) -> int {
    return node == nil ? 0 : node.height
}

set_height :: proc(node: ^Node) {
    node.height = 1 + max(height(node.left), height(node.right))
}

balance_factor :: proc(node: ^Node) -> int {
    return node == nil ? 0 : height(node.left) - height(node.right)
}