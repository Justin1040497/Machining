package org.dromara.framelean.controller;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.dromara.framelean.config.RequestIpResolver;
import org.dromara.framelean.domain.FrameleanDtos.CreateDownloadTicketRequest;
import org.dromara.framelean.domain.FrameleanDtos.DownloadTicketCreateResponse;
import org.dromara.framelean.domain.FrameleanDtos.DownloadTicketRequest;
import org.dromara.framelean.domain.FrameleanDtos.DownloadTicketResponse;
import org.dromara.framelean.domain.FrameleanDtos.ReleaseNotesListItem;
import org.dromara.framelean.domain.FrameleanDtos.UpdateCheckResponse;
import org.dromara.framelean.service.UpdateService;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.util.List;

@RestController
@RequestMapping("/api/v1/releases")
@RequiredArgsConstructor
public class ReleaseController {
    private final UpdateService updateService;
    private final RequestIpResolver requestIpResolver;

    @GetMapping("/latest")
    public UpdateCheckResponse checkLatest(
        @RequestParam String currentVersion,
        @RequestParam int currentBuild,
        @RequestParam String platform,
        @RequestParam(defaultValue = "stable") String channel,
        @RequestParam(required = false) String installId,
        HttpServletRequest request
    ) {
        return updateService.checkForUpdate(
            currentVersion,
            currentBuild,
            platform,
            channel,
            installId,
            requestIpResolver.resolve(request),
            request.getHeader("User-Agent")
        );
    }

    @GetMapping(value = "/{version}/notes", produces = "text/markdown; charset=utf-8")
    public ResponseEntity<String> releaseNotes(@PathVariable String version) {
        return ResponseEntity.ok()
            .contentType(MediaType.parseMediaType("text/markdown; charset=utf-8"))
            .body(updateService.getReleaseNotes(version));
    }

    @GetMapping("/notes")
    public List<ReleaseNotesListItem> releaseNotesList(@RequestParam(defaultValue = "stable") String channel) {
        return updateService.listReleaseNotes(channel);
    }

    @PostMapping("/download-ticket")
    public ResponseEntity<DownloadTicketCreateResponse> createDownloadTicket(
        @Valid @RequestBody CreateDownloadTicketRequest body,
        HttpServletRequest request
    ) {
        DownloadTicketCreateResponse response = updateService.createDownloadTicket(
            body.version(),
            body.platform(),
            body.installId(),
            requestIpResolver.resolve(request)
        );
        return ResponseEntity.created(URI.create("/api/v1/releases/download-ticket/" + response.ticketId())).body(response);
    }

    @PostMapping("/download-ticket/{ticketId}/resolve")
    public DownloadTicketResponse resolveDownloadTicket(@PathVariable String ticketId) {
        return updateService.resolveDownloadTicket(ticketId);
    }

    @PostMapping("/{version}/packages/{platform}/ticket")
    public DownloadTicketResponse downloadTicket(
        @PathVariable String version,
        @PathVariable String platform,
        @Valid @RequestBody DownloadTicketRequest body,
        HttpServletRequest request
    ) {
        return updateService.createLegacyDownloadTicket(version, platform, body.installId(), requestIpResolver.resolve(request));
    }
}
