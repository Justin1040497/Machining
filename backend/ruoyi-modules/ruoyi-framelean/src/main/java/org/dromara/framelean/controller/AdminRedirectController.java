package org.dromara.framelean.controller;

import cn.dev33.satoken.annotation.SaIgnore;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@SaIgnore
@Controller
public class AdminRedirectController {

    @GetMapping("/web")
    public String oldAdminWebEntry() {
        return "redirect:/";
    }

    @GetMapping({
        "/login",
        "/401",
        "/redirect/**",
        "/index",
        "/user/**",
        "/framelean/**"
    })
    public String adminWebRoute() {
        return "forward:/index.html";
    }
}
