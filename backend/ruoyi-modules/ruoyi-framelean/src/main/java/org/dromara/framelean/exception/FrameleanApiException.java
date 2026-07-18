package org.dromara.framelean.exception;

import org.springframework.http.HttpStatus;

public class FrameleanApiException extends RuntimeException {
    private final String code;
    private final HttpStatus status;

    public FrameleanApiException(String code, HttpStatus status, String message) {
        super(message);
        this.code = code;
        this.status = status;
    }

    public String getCode() {
        return code;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public static FrameleanApiException notFound(String message) {
        return new FrameleanApiException("not_found", HttpStatus.NOT_FOUND, message);
    }

    public static FrameleanApiException conflict(String message) {
        return new FrameleanApiException("release_conflict", HttpStatus.CONFLICT, message);
    }

    public static FrameleanApiException badRequest(String code, String message) {
        return new FrameleanApiException(code, HttpStatus.BAD_REQUEST, message);
    }

    public static FrameleanApiException forbidden(String code, String message) {
        return new FrameleanApiException(code, HttpStatus.FORBIDDEN, message);
    }
}
