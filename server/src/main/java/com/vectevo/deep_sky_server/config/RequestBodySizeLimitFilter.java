package com.vectevo.deep_sky_server.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Enforces request-body byte limits across all {@code /api/v1/**} endpoints, including
 * unauthenticated public routes not covered by {@link DeviceAuthFilter} ({@code AU-14}).
 */
public class RequestBodySizeLimitFilter extends OncePerRequestFilter {

	public static final int MAX_PUBLIC_BODY_BYTES = 64 * 1024;
	public static final int MAX_API_BODY_BYTES = 1024 * 1024;

	@Override
	protected boolean shouldNotFilter(HttpServletRequest request) {
		String path = request.getRequestURI();
		return path == null || !path.startsWith("/api/v1/");
	}

	@Override
	protected void doFilterInternal(
			HttpServletRequest request,
			HttpServletResponse response,
			FilterChain filterChain)
			throws ServletException, IOException {
		int maxBytes = PublicRoutes.isPublicApiRequest(request.getMethod(), request.getRequestURI())
				? MAX_PUBLIC_BODY_BYTES
				: MAX_API_BODY_BYTES;

		long contentLength = request.getContentLengthLong();
		if (contentLength > maxBytes) {
			rejectTooLarge(response);
			return;
		}

		try {
			filterChain.doFilter(new LimitedBodyHttpServletRequest(request, maxBytes), response);
		} catch (ServletException ex) {
			if (containsBodyTooLarge(ex)) {
				if (!response.isCommitted()) {
					rejectTooLarge(response);
				}
				return;
			}
			throw ex;
		} catch (RuntimeException | IOException ex) {
			if (containsBodyTooLarge(ex)) {
				if (!response.isCommitted()) {
					rejectTooLarge(response);
				}
				return;
			}
			throw ex;
		}
	}

	private static boolean containsBodyTooLarge(Throwable ex) {
		Throwable cur = ex;
		while (cur != null) {
			if (cur instanceof BodyTooLargeException) {
				return true;
			}
			cur = cur.getCause();
		}
		return false;
	}

	private static void rejectTooLarge(HttpServletResponse response) throws IOException {
		response.setStatus(HttpServletResponse.SC_REQUEST_ENTITY_TOO_LARGE);
		response.setContentType(MediaType.APPLICATION_JSON_VALUE);
		response.setCharacterEncoding(StandardCharsets.UTF_8.name());
		response.getWriter().write(
				"{\"code\":\"PAYLOAD_TOO_LARGE\",\"message\":\"Request body exceeds maximum allowed size\","
						+ "\"timestamp\":\"" + Instant.now() + "\"}");
	}

	private static final class BodyTooLargeException extends IOException {
		BodyTooLargeException() {
			super("Request body exceeds maximum allowed size");
		}
	}

	private static final class LimitedBodyHttpServletRequest extends HttpServletRequestWrapper {
		private final int maxBytes;

		private LimitedBodyHttpServletRequest(HttpServletRequest request, int maxBytes) {
			super(request);
			this.maxBytes = maxBytes;
		}

		@Override
		public ServletInputStream getInputStream() throws IOException {
			ServletInputStream delegate = super.getInputStream();
			return new ServletInputStream() {
				private long bytesRead = 0;

				@Override
				public int read() throws IOException {
					int b = delegate.read();
					if (b != -1 && ++bytesRead > maxBytes) {
						throw new BodyTooLargeException();
					}
					return b;
				}

				@Override
				public int read(byte[] b, int off, int len) throws IOException {
					int n = delegate.read(b, off, len);
					if (n > 0) {
						bytesRead += n;
						if (bytesRead > maxBytes) {
							throw new BodyTooLargeException();
						}
					}
					return n;
				}

				@Override
				public boolean isFinished() {
					return delegate.isFinished();
				}

				@Override
				public boolean isReady() {
					return delegate.isReady();
				}

				@Override
				public void setReadListener(ReadListener readListener) {
					delegate.setReadListener(readListener);
				}
			};
		}

		@Override
		public BufferedReader getReader() throws IOException {
			return new BufferedReader(new InputStreamReader(getInputStream(), StandardCharsets.UTF_8));
		}
	}
}
