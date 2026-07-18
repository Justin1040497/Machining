package org.dromara.web.controller;

import cn.dev33.satoken.annotation.SaIgnore;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * 首页
 *
 * @author Lion Li
 */
@SaIgnore
@RequiredArgsConstructor
@Controller
public class IndexController {

    /**
     * 访问首页，进入 plus-ui 后台。
     */
    @GetMapping("/")
    public String index() {
        return "forward:/index.html";
    }

}
